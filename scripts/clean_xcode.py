import os
import shutil
import time
import argparse
from datetime import datetime, timedelta

# Configuration
DEFAULT_BASE_DIR = os.path.expanduser("/Users/midoll/Library/Developer/Xcode")

# Whitelist for iOS DeviceSupport
# Add the version strings you want to keep, e.g., "16.4", "17.0"
IOS_DEVICE_SUPPORT_WHITELIST = [
    # Midoll's xs max
    "iPhone11,6 18.7.2 (22H124)",
    # Midoll's 15
    "iPhone15,4 18.5 (22F76)",
]

def get_size(path):
    total_size = 0
    try:
        if os.path.isfile(path):
            return os.path.getsize(path)
        for dirpath, _, filenames in os.walk(path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if not os.path.islink(fp):
                    total_size += os.path.getsize(fp)
    except Exception:
        pass
    return total_size

def format_size(size):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size < 1024:
            return f"{size:.2f} {unit}"
        size /= 1024
    return f"{size:.2f} PB"

def get_file_age_days(path):
    try:
        mtime = os.path.getmtime(path)
        return (time.time() - mtime) / (24 * 3600)
    except FileNotFoundError:
        return 0

class Cleaner:
    def __init__(self, base_dir, dry_run=True):
        self.base_dir = base_dir
        self.dry_run = dry_run
        self.total_freed_space = 0
        self.total_deleted_files = 0
        self.deleted_items = []

    def log(self, message):
        print(message)

    def delete_path(self, path, reason):
        size = get_size(path)
        self.deleted_items.append((path, size, reason))
        self.total_freed_space += size
        self.total_deleted_files += 1
        
        if self.dry_run:
            self.log(f"[DRY-RUN] Would delete: {path} ({format_size(size)}) - Reason: {reason}")
        else:
            try:
                if os.path.isfile(path) or os.path.islink(path):
                    os.remove(path)
                elif os.path.isdir(path):
                    shutil.rmtree(path)
                self.log(f"[DELETED] {path} ({format_size(size)}) - Reason: {reason}")
            except Exception as e:
                self.log(f"[ERROR] Failed to delete {path}: {e}")

    def process_archives(self):
        target_dir = os.path.join(self.base_dir, "Archives")
        if not os.path.exists(target_dir):
            return

        self.log(f"\nScanning {target_dir}...")
        # Archives are usually organized by date YYYY-MM-DD
        for date_dir in os.listdir(target_dir):
            full_path = os.path.join(target_dir, date_dir)
            if get_file_age_days(full_path) > 90: # 3 months
                self.delete_path(full_path, "Older than 3 months")

    def process_derived_data(self):
        target_dir = os.path.join(self.base_dir, "DerivedData")
        if not os.path.exists(target_dir):
            return

        self.log(f"\nScanning {target_dir}...")
        for item in os.listdir(target_dir):
            full_path = os.path.join(target_dir, item)
            if item.startswith("Pods-") or item.startswith("Runner-"):
                if get_file_age_days(full_path) > 30: # 1 month
                    self.delete_path(full_path, "Pods/Runner prefix and older than 1 month")

    def process_ios_device_support(self):
        target_dir = os.path.join(self.base_dir, "iOS DeviceSupport")
        if not os.path.exists(target_dir):
            return

        self.log(f"\nScanning {target_dir}...")
        for item in os.listdir(target_dir):
            full_path = os.path.join(target_dir, item)
            
            # Check whitelist
            is_whitelisted = any(w in item for w in IOS_DEVICE_SUPPORT_WHITELIST)
            
            if not is_whitelisted:
                if get_file_age_days(full_path) > 7: # 1 week
                    self.delete_path(full_path, "Not in whitelist and older than 1 week")

    def process_documentation_cache(self):
        # Additional strategy
        target_dir = os.path.join(self.base_dir, "DocumentationCache")
        if not os.path.exists(target_dir):
            return
            
        self.log(f"\nScanning {target_dir}...")
        for item in os.listdir(target_dir):
            full_path = os.path.join(target_dir, item)
            if get_file_age_days(full_path) > 30:
                self.delete_path(full_path, "Documentation cache older than 1 month")

    def run(self):
        self.process_archives()
        self.process_derived_data()
        self.process_ios_device_support()
        self.process_documentation_cache()
        
        print("\n" + "="*40)
        print("Summary")
        print("="*40)
        print(f"Total items processed for deletion: {self.total_deleted_files}")
        print(f"Total space to be freed: {format_size(self.total_freed_space)}")
        
        if self.dry_run:
            print("\nThis was a DRY RUN. No files were deleted.")
            print("To actually delete files, run with --delete")

def main():
    parser = argparse.ArgumentParser(description="Clean Xcode directories.")
    parser.add_argument("--delete", action="store_true", help="Actually delete files. Default is dry-run.")
    parser.add_argument("--base-dir", default=DEFAULT_BASE_DIR, help="Base directory to clean.")
    args = parser.parse_args()

    cleaner = Cleaner(base_dir=args.base_dir, dry_run=not args.delete)
    
    if args.delete:
        print("WARNING: You are about to delete files.")
        response = input("Are you sure you want to continue? (yes/no): ")
        if response.lower() != "yes":
            print("Aborted.")
            return

    cleaner.run()

if __name__ == "__main__":
    main()
