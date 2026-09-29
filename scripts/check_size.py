import os

def get_large_files(root_dir, top_n=20):
    file_list = []
    for root, dirs, files in os.walk(root_dir):
        if '.git' in root or 'build' in root or '.dart_tool' in root:
            continue
        for name in files:
            filepath = os.path.join(root, name)
            try:
                size = os.path.getsize(filepath)
                file_list.append((filepath, size))
            except OSError:
                pass
    
    file_list.sort(key=lambda x: x[1], reverse=True)
    return file_list[:top_n]

if __name__ == '__main__':
    top_files = get_large_files('.')
    for path, size in top_files:
        print(f"{size/1024/1024:.2f} MB: {path}")
