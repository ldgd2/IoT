import sqlite3
import json
from typing import Any, Dict, List, TypeVar, Type, Optional
from hub.core.config import DB_FILE

T = TypeVar('T', bound='BaseModel')

class Database:
    @staticmethod
    def get_connection():
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        return conn

    @staticmethod
    def execute(query: str, params: tuple = ()) -> sqlite3.Cursor:
        with Database.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            return cursor

class Field:
    def __init__(self, type_name: str, primary_key: bool = False, default: Any = None):
        self.type_name = type_name
        self.primary_key = primary_key
        self.default = default

class BaseModel:
    __table__ = ""

    def __init__(self, **kwargs):
        for key, field in self._get_fields().items():
            setattr(self, key, kwargs.get(key, field.default))

    @classmethod
    def _get_fields(cls) -> Dict[str, Field]:
        return {k: v for k, v in cls.__dict__.items() if isinstance(v, Field)}

    @classmethod
    def migrate_all(cls) -> dict:
        """Migra todas las clases hijas al vuelo y retorna un reporte"""
        report = {"created": [], "exists": []}
        for subclass in cls.__subclasses__():
            status = subclass.create_table()
            report[status].append(subclass.__table__)
        return report

    @classmethod
    def create_table(cls) -> str:
        # Check if table exists
        cursor = Database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (cls.__table__,))
        if cursor.fetchone():
            return "exists"
            
        fields = []
        for name, field in cls._get_fields().items():
            f_def = f"{name} {field.type_name}"
            if field.primary_key:
                f_def += " PRIMARY KEY"
            fields.append(f_def)
        query = f"CREATE TABLE {cls.__table__} ({', '.join(fields)});"
        Database.execute(query)
        return "created"

    def save(self):
        fields = self._get_fields()
        columns = list(fields.keys())
        
        values = []
        for col in columns:
            val = getattr(self, col)
            if isinstance(val, (dict, list)):
                val = json.dumps(val)
            values.append(val)
            
        placeholders = ", ".join(["?"] * len(columns))
        pk = next((k for k, v in fields.items() if v.primary_key), columns[0])
        update_set = ", ".join([f"{col} = excluded.{col}" for col in columns if col != pk])
        
        query = f"""
            INSERT INTO {self.__table__} ({', '.join(columns)}) 
            VALUES ({placeholders})
            ON CONFLICT({pk}) DO UPDATE SET {update_set};
        """
        Database.execute(query, tuple(values))

    @classmethod
    def all(cls: Type[T]) -> List[T]:
        cursor = Database.execute(f"SELECT * FROM {cls.__table__}")
        rows = cursor.fetchall()
        results = []
        for r in rows:
            data = dict(r)
            for k, v in data.items():
                if isinstance(v, str) and (v.startswith('{') or v.startswith('[')):
                    try:
                        data[k] = json.loads(v)
                    except json.JSONDecodeError:
                        pass
            results.append(cls(**data))
        return results

    @classmethod
    def get(cls: Type[T], pk_value: Any) -> Optional[T]:
        pk = next((k for k, v in cls._get_fields().items() if v.primary_key), None)
        if not pk: return None
        cursor = Database.execute(f"SELECT * FROM {cls.__table__} WHERE {pk} = ?", (pk_value,))
        r = cursor.fetchone()
        if not r: return None
        
        data = dict(r)
        for k, v in data.items():
            if isinstance(v, str) and (v.startswith('{') or v.startswith('[')):
                try:
                    data[k] = json.loads(v)
                except json.JSONDecodeError:
                    pass
        return cls(**data)
    
    def to_dict(self):
        return {k: getattr(self, k) for k in self._get_fields()}
