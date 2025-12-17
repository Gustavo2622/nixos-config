# clipboard-jh (cb)

Cross-platform clipboard manager with history, piping, and multi-clipboard support.

## Basic Usage

```bash
# Copy text
echo "hello" | cb copy
cb copy "hello world"

# Paste
cb paste

# Copy a file
cb copy myfile.txt

# Copy multiple files
cb copy file1.txt file2.txt image.png
```

## Piping

```bash
# Pipe through commands
cb paste | jq '.data' | cb copy

# Chain with other tools
cat data.json | cb copy
cb paste | grep "error" | cb copy

# Copy command output
ls -la | cb copy
```

## History

```bash
# Show clipboard history
cb history

# Paste from history (by index)
cb paste 1    # previous clipboard entry
cb paste 5    # 5 entries ago

# Clear history
cb clear
```

## Multiple Clipboards

```bash
# Use named clipboards
cb copy --clipboard work "meeting notes"
cb copy --clipboard personal "shopping list"

# Paste from a specific clipboard
cb paste --clipboard work
```

## Content Info

```bash
# Show what's in the clipboard
cb show

# Show clipboard status (type, size)
cb status
```

## Useful Patterns

```bash
# Copy file contents without cat
cb copy < config.yaml

# Quick backup of clipboard before overwriting
cb paste > /tmp/cb-backup.txt

# Copy with format preservation (images, rich text)
cb copy image.png        # copies as image, not filename

# Merge multiple items
cb copy "line1"
cb add "line2"           # appends to current clipboard
cb paste                 # "line1\nline2"
```
