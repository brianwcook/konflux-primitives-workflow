#!/usr/bin/env python3
"""
Transform lockfile from file:/// references to OCI references using compose file mapping.

This script implements the transformation layer described in the architecture:
1. Reads a compose file to get package name -> OCI reference mapping
2. Reads a lockfile with file:/// references (from rpm-lockfile-prototype)
3. Transforms file:/// references to OCI references
4. Outputs a new lockfile compatible with Hermeto
"""

import yaml
import re
import sys
import argparse
from pathlib import Path


def extract_nvr_from_rpm_path(rpm_path):
    """Extract name-version-release from RPM file path."""
    # Get filename without path and .rpm extension
    filename = Path(rpm_path).stem
    
    # Remove architecture suffix (last dot-separated component)
    nvr = re.sub(r'\.[^.]+$', '', filename)
    return nvr


def extract_package_name(nvr):
    """Extract package name from NVR."""
    # Package name is everything before the first dash that's followed by a version
    # This is a simplified approach - real RPM parsing would be more robust
    match = re.match(r'^([^-]+(?:-[^0-9][^-]*)*)-[0-9]', nvr)
    if match:
        return match.group(1)
    return nvr.split('-')[0]  # Fallback


def load_compose_file(compose_path):
    """Load compose file and create package name -> OCI reference mapping."""
    with open(compose_path, 'r') as f:
        compose = yaml.safe_load(f)
    
    mapping = {}
    if 'packages' in compose:
        for pkg_name, pkg_info in compose['packages'].items():
            if 'oci_ref' in pkg_info:
                mapping[pkg_name] = pkg_info['oci_ref']
    
    return mapping


def transform_lockfile(input_path, output_path, compose_mapping):
    """Transform lockfile from file:/// to OCI references."""
    with open(input_path, 'r') as f:
        lockfile = yaml.safe_load(f)
    
    if 'packages' not in lockfile:
        print("Warning: No packages section found in lockfile")
        return
    
    transformed_count = 0
    missing_mappings = []
    
    for package in lockfile['packages']:
        if 'rpm_path' in package:
            # Extract package info from RPM path
            rpm_path = package['rpm_path']
            
            # Handle file:/// URLs
            if rpm_path.startswith('file://'):
                rpm_path = rpm_path[7:]  # Remove file:// prefix
            
            # Extract NVR and package name
            nvr = extract_nvr_from_rpm_path(rpm_path)
            pkg_name = extract_package_name(nvr)
            
            print(f"Processing: {rpm_path} -> {pkg_name} ({nvr})")
            
            # Look up OCI reference in compose mapping
            if pkg_name in compose_mapping:
                oci_ref = compose_mapping[pkg_name]
                package['oci_ref'] = oci_ref
                
                # Keep original for reference
                package['original_rpm_path'] = package['rpm_path']
                
                # Update rpm_path to indicate OCI source
                package['rpm_path'] = f"oci://{oci_ref.replace('oci://', '')}"
                
                transformed_count += 1
                print(f"  -> Transformed to: {oci_ref}")
            else:
                missing_mappings.append(pkg_name)
                print(f"  -> Warning: No OCI mapping found for package '{pkg_name}'")
    
    # Write transformed lockfile
    with open(output_path, 'w') as f:
        yaml.dump(lockfile, f, default_flow_style=False, sort_keys=False)
    
    print(f"\nTransformation complete:")
    print(f"  Packages transformed: {transformed_count}")
    print(f"  Missing mappings: {len(missing_mappings)}")
    
    if missing_mappings:
        print(f"  Missing packages: {', '.join(missing_mappings)}")
    
    return transformed_count, missing_mappings


def main():
    parser = argparse.ArgumentParser(description='Transform lockfile file:/// references to OCI references')
    parser.add_argument('compose_file', help='Path to compose file with OCI mappings')
    parser.add_argument('input_lockfile', help='Input lockfile with file:/// references')
    parser.add_argument('output_lockfile', help='Output lockfile with OCI references')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    # Load compose file mapping
    try:
        print(f"Loading compose file: {args.compose_file}")
        compose_mapping = load_compose_file(args.compose_file)
        print(f"Loaded {len(compose_mapping)} package mappings")
        
        if args.verbose:
            for pkg, ref in compose_mapping.items():
                print(f"  {pkg} -> {ref}")
        
    except Exception as e:
        print(f"Error loading compose file: {e}")
        return 1
    
    # Transform lockfile
    try:
        print(f"\nTransforming lockfile: {args.input_lockfile} -> {args.output_lockfile}")
        transformed_count, missing = transform_lockfile(
            args.input_lockfile, 
            args.output_lockfile, 
            compose_mapping
        )
        
        if missing:
            print(f"\nWarning: {len(missing)} packages not found in compose file")
            return 1
            
        print(f"\nSuccess: Transformed {transformed_count} packages")
        return 0
        
    except Exception as e:
        print(f"Error transforming lockfile: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())