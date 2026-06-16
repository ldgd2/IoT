import os
import re

svg_dir = r'c:\Users\ldgd2\OneDrive\Documentos\Proyectos_lider\python\IoT\hub\templates\UI\icons\svg'
count = 0
for file in os.listdir(svg_dir):
    if file.endswith('.svg'):
        path = os.path.join(svg_dir, file)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = re.sub(r'fill=\'#[A-Fa-f0-9]+\'', 'fill="currentColor"', content)
        new_content = re.sub(r'fill=\"#[A-Fa-f0-9]+\"', 'fill="currentColor"', new_content)
        
        if new_content != content:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            count += 1

print(f'Updated {count} SVGs')
