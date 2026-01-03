#!/usr/bin/env python3
"""
Script to add new Swift files to the Xcode project
"""
import re
import uuid

# Generate unique IDs for the new files
def generate_id():
    """Generate a 24-character hex ID similar to Xcode's format"""
    return ''.join([f'{ord(c):02X}' for c in str(uuid.uuid4())[:12]])

# File to add
files_to_add = [
    {
        'name': 'LockSchedule.swift',
        'group': 'Models',
        'path': 'Models/LockSchedule.swift'
    },
    {
        'name': 'ScheduleManager.swift',
        'group': 'Services',
        'path': 'Services/ScheduleManager.swift'
    },
    {
        'name': 'SchedulesView.swift',
        'group': 'Views',
        'path': 'Views/SchedulesView.swift'
    }
]

project_file = 'LemmeGo/LemmeGo.xcodeproj/project.pbxproj'

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# For each file, generate IDs and add entries
for file_info in files_to_add:
    file_ref_id = generate_id()
    build_file_id = generate_id()

    filename = file_info['name']
    filepath = file_info['path']
    group = file_info['group']

    # Add PBXBuildFile entry (near the top of the file)
    build_file_entry = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n'

    # Find the PBXBuildFile section and add our entry
    pbx_build_section = re.search(r'(/\* Begin PBXBuildFile section \*/\n)', content)
    if pbx_build_section:
        insert_pos = pbx_build_section.end()
        content = content[:insert_pos] + build_file_entry + content[insert_pos:]

    # Add PBXFileReference entry
    file_ref_entry = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

    # Find the PBXFileReference section and add our entry
    pbx_file_section = re.search(r'(/\* Begin PBXFileReference section \*/\n)', content)
    if pbx_file_section:
        insert_pos = pbx_file_section.end()
        content = content[:insert_pos] + file_ref_entry + content[insert_pos:]

    # Add to the appropriate group (Models or Views)
    group_pattern = rf'(/\* {group} \*/.*?children = \(\n)(.*?)(\);)'
    group_match = re.search(group_pattern, content, re.DOTALL)
    if group_match:
        children_section = group_match.group(2)
        new_child_entry = f'\t\t\t\t{file_ref_id} /* {filename} */,\n'
        updated_children = children_section + new_child_entry
        content = content[:group_match.start(2)] + updated_children + content[group_match.end(2):]

    # Add to Sources Build Phase
    sources_pattern = r'(/\* Sources \*/.*?files = \(\n)(.*?)(\);)'
    sources_match = re.search(sources_pattern, content, re.DOTALL)
    if sources_match:
        sources_section = sources_match.group(2)
        new_source_entry = f'\t\t\t\t{build_file_id} /* {filename} in Sources */,\n'
        updated_sources = sources_section + new_source_entry
        content = content[:sources_match.start(2)] + updated_sources + content[sources_match.end(2):]

# Write the updated project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully added files to Xcode project:")
for file_info in files_to_add:
    print(f"   - {file_info['name']}")
print("\nYou can now build the project!")
