import glob
import os

def clean_svgs():
    svg_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates", "UI", "icons", "svg")
    files = glob.glob(os.path.join(svg_dir, "*.svg"))
    count = 0
    for f in files:
        try:
            with open(f, "r", encoding="utf-8") as file:
                content = file.read()
            if 'transform="scale(0.5) translate(12 12)"' in content:
                new_content = content.replace(' transform="scale(0.5) translate(12 12)"', '')
                with open(f, "w", encoding="utf-8") as file:
                    file.write(new_content)
                count += 1
        except Exception as e:
            pass
    print(f"Cleaned {count} SVG icons successfully!")

if __name__ == "__main__":
    clean_svgs()
