#!/usr/bin/env python3
"""
prune_imap.py - Delete emails older than a specified date from IMAP server
"""

import imaplib
import os
import sys
import argparse
from datetime import datetime, timedelta

def get_folders_to_prune(mail, sync_folders_config):
    """Parse SYNC_FOLDERS config and return list of folders to prune"""
    if sync_folders_config == "*":
        # Get all folders from server
        try:
            typ, folders = mail.list()
            if typ != 'OK':
                print("Error: Could not list folders from server")
                return ['INBOX']  # Fallback to INBOX only
            
            folder_names = []
            for folder in folders:
                # Parse folder list response: b'(\\HasNoChildren) "/" "INBOX"'
                folder_str = folder.decode('utf-8')
                # Extract folder name (last quoted part)
                parts = folder_str.split('"')
                if len(parts) >= 3:
                    folder_name = parts[-2]  # Second to last quoted part
                    folder_names.append(folder_name)
            
            return folder_names if folder_names else ['INBOX']
        except Exception as e:
            print(f"Warning: Could not get folder list, using INBOX only: {e}")
            return ['INBOX']
    else:
        # Parse specific folder list
        # Handle quoted folder names and split by spaces
        import shlex
        try:
            return shlex.split(sync_folders_config)
        except ValueError:
            # Fallback to simple split if shlex fails
            return sync_folders_config.split()

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Delete emails older than a specified date from IMAP server')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Show what would be deleted without actually deleting anything')
    args = parser.parse_args()
    
    # Check environment variable for dry run mode
    env_dry_run = os.environ.get('DRY_RUN', 'false').lower() == 'true'
    if env_dry_run and not args.dry_run:
        args.dry_run = True
        print("Dry run mode enabled via environment variable")
    
    # Get credentials and server info from environment variables
    email_user = os.environ.get('EMAIL_USER')
    email_pass = os.environ.get('EMAIL_PASS')
    imap_host = os.environ.get('IMAP_HOST')
    imap_port = os.environ.get('IMAP_PORT', '993')
    cutoff_date = os.environ.get('CUTOFF_DATE')
    prune_days = os.environ.get('PRUNE_DAYS', '365')
    sync_folders = os.environ.get('SYNC_FOLDERS', '*')
    
    if not all([email_user, email_pass, imap_host, cutoff_date]):
        print("Error: Missing required environment variables")
        print("Required: EMAIL_USER, EMAIL_PASS, IMAP_HOST, CUTOFF_DATE")
        sys.exit(1)
    
    try:
        print(f"Connecting to IMAP server {imap_host}:{imap_port}...")
        # Connect to IMAP server
        mail = imaplib.IMAP4_SSL(imap_host, int(imap_port))
        mail.login(email_user, email_pass)
        
        # Get folders to prune based on SYNC_FOLDERS config
        folders_to_prune = get_folders_to_prune(mail, sync_folders)
        print(f"Folders to prune: {folders_to_prune}")
        
        total_deleted = 0
        search_criteria = f'BEFORE {cutoff_date}'
        
        if args.dry_run:
            print(f"=== DRY RUN MODE - No emails will actually be deleted ===")
        
        print(f"Searching for emails older than {prune_days} days with criteria: {search_criteria}")
        
        for folder in folders_to_prune:
            try:
                print(f"\nProcessing folder: {folder}")
                
                # Select folder
                typ, data = mail.select(folder)
                if typ != 'OK':
                    print(f"Warning: Could not select folder '{folder}': {data}")
                    continue
                
                # Search for matching messages
                typ, msg_ids = mail.search(None, search_criteria)
                
                if typ != 'OK':
                    print(f"Error searching for messages in folder '{folder}'")
                    continue
                    
                message_ids = msg_ids[0].split()
                
                if len(message_ids) > 0:
                    if args.dry_run:
                        print(f"[DRY RUN] Would delete {len(message_ids)} messages from '{folder}'")
                        total_deleted += len(message_ids)
                    else:
                        print(f"Found {len(message_ids)} messages to delete in '{folder}'")
                        # Mark messages for deletion
                        for msg_id in message_ids:
                            mail.store(msg_id, '+FLAGS', '\\Deleted')
                        
                        # Expunge to permanently delete
                        mail.expunge()
                        total_deleted += len(message_ids)
                        print(f"Successfully deleted {len(message_ids)} messages from '{folder}'")
                else:
                    print(f"No messages older than {prune_days} days found in '{folder}'")
                    
            except Exception as e:
                print(f"Error processing folder '{folder}': {e}")
                continue
        
        if args.dry_run:
            print(f"\n[DRY RUN] Total messages that would be deleted across all folders: {total_deleted}")
        else:
            print(f"\nTotal messages deleted across all folders: {total_deleted}")
        
        # Close connection
        mail.logout()
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()