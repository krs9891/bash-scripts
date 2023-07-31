#!/bin/bash

currentVersion="0.0.1"

show_help() {
    echo "Description: Bash tool to transfer files from the command line."
    echo "Usage:"
    echo "  -d <directory> <file_id> <file_name>    Download a single file from transfer.sh to the specified directory."
    echo "  -h                                     Show this help message."
    echo "  -v                                     Get the tool version."
    echo "Examples:"
    echo "  ./transfer.sh test.txt ..."
}

show_version() {
    echo $currentVersion
}

upload_files() {
    echo "Uploading files: $@"
}

download_file() {
    local directory="$1"
    local file_id="$2"
    local file_name="$3"
    echo "Downloading file with ID: $file_id to directory: $directory with name: $file_name"
}

# Parse flags using getopts
while getopts ":d:hv" opt; do
    case $opt in
    d)
        directory="$OPTARG"
        shift $((OPTIND - 1))
        ;;
    h)
        show_help
        exit 0
        ;;
    v)
        show_version
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done

# Shift to the next argument after flags
shift $((OPTIND - 1))

# Check if -d flag is provided to trigger the download
if [[ -n "$directory" && $# -eq 2 ]]; then
    file_id="$1"
    file_name="$2"
    download_file "$directory" "$file_id" "$file_name"
elif [[ $# -gt 0 ]]; then
    # If no -d flag, assume it's an upload operation
    upload_files "$@"
else
    # If no flags or arguments provided, show help message
    echo "Invalid number of arguments for the download operation."
    show_help
    exit 1
fi
