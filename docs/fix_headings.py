#!/usr/bin/env python3
"""
Script to fix all links in README.md files.
Converts links with FORGE-V5 in the path to the correct format without FORGE-V5.
Pattern: [[docs/FORGE-V5/...|...]] -> [[docs/...|...]]
"""

import re
from pathlib import Path

def fix_links_in_file(file_path):
    """Fix all links containing FORGE-V5 in a README.md file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        lines = content.split('\n')
        modified = False
        fixed_lines = []
        
        # Process all lines and fix any links containing FORGE-V5
        for i, line in enumerate(lines):
            original_line = line
            # Replace FORGE-V5/ in all links that match the pattern
            # Pattern: [[docs/FORGE-V5/...|...]] -> [[docs/...|...]]
            new_line = re.sub(
                r'\[\[docs/FORGE-V5/([^|]+)\|(.+?)\]\]',
                r'[[docs/\1|\2]]',
                line
            )
            
            if new_line != original_line:
                lines[i] = new_line
                modified = True
                fixed_lines.append((i + 1, original_line, new_line))
        
        if modified:
            # Write back the modified content
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(lines))
            print(f"Fixed: {file_path}")
            for line_num, old, new in fixed_lines:
                print(f"  Line {line_num}:")
                print(f"    Old: {old}")
                print(f"    New: {new}")
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function to recursively process all README.md files."""
    docs_dir = Path(__file__).parent  # ./docs directory
    
    if not docs_dir.exists():
        print(f"Error: {docs_dir} does not exist")
        return
    
    readme_files = list(docs_dir.rglob('README.md'))
    
    if not readme_files:
        print("No README.md files found")
        return
    
    print(f"Found {len(readme_files)} README.md file(s)")
    print("-" * 60)
    
    fixed_count = 0
    for readme_file in readme_files:
        if fix_links_in_file(readme_file):
            fixed_count += 1
    
    print("-" * 60)
    print(f"Processing complete. Fixed {fixed_count} file(s).")

if __name__ == '__main__':
    main()

