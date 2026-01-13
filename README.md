# Mikro Taskwarrior

A lightweight, Taskwarrior-inspired task management plugin for Neovim. Manage your tasks directly from your editor with a simple, intuitive interface.

## Features

- **Task Management**: Create, list, modify, and complete tasks
- **Smart Urgency Calculation**: Tasks are automatically sorted by urgency using Taskwarrior-compatible algorithms
- **Tag Support**: Organize tasks with tags using `+tag` syntax
- **Due Dates**: Set due dates with smart date parsing (e.g., `due:today`, `due:tomorrow`, `due:1w`)
- **Filtering**: Filter tasks by tags (include with `+tag`, exclude with `-tag`)
- **Floating Window UI**: Beautiful floating window display for task lists
- **JSON Storage**: Tasks are stored in a simple JSON file

## Installation

### Using lazy.nvim (AstroNvim)

1. Clone this repository to your local directory:
```bash
git clone <repository-url> ~/coding/Mikro_Taskwarrior
```

2. Create a plugin spec file at `~/.config/nvim/lua/plugins/mikro_taskwarrior.lua`:
```lua
return {
  "mikro_taskwarrior",
  dir = "/path/to/Mikro_Taskwarrior",
  lazy = false,
  priority = 1000,
}
```

3. Restart Neovim or run `:Lazy sync`

### Manual Installation

1. Clone this repository to your Neovim runtime path:
```bash
git clone <repository-url> ~/.config/nvim/pack/plugins/start/mikro_taskwarrior
```

2. Restart Neovim

## Usage

### Commands

The plugin provides a `:Task` command with the following subcommands:

#### List Tasks

```vim
:Task list                    " List all open tasks
:Task +work list              " List tasks with 'work' tag
:Task +work -urgent list      " List tasks with 'work' tag but without 'urgent' tag
:Task 1 list                  " Show detailed view of task ID 1
```

#### Add Task

```vim
:Task add Buy groceries
:Task add Review PR due:tomorrow +work
:Task add Fix bug due:1w +urgent +coding
```

**Due Date Formats:**
- `due:today` - Today
- `due:tomorrow` - Tomorrow
- `due:1d` - 1 day from now
- `due:2w` - 2 weeks from now
- `due:1m` - 1 month from now (approximate, 30 days)
- `due:monday` or `due:mon` - Next Monday
- `due:YYYY-MM-DD` - Specific date (e.g., `due:2024-12-25`)

**Tags:**
- Use `+tag` to add tags to tasks
- Multiple tags: `+work +urgent +coding`

#### Modify Tasks

```vim
:Task +work modify due:tomorrow    " Set due date for all tasks with 'work' tag
:Task 1 modify due:1w +urgent     " Modify task ID 1: set due date and add tag
:Task +coding modify -urgent       " Remove 'urgent' tag from all 'coding' tasks
```

**Modification Options:**
- `due:...` - Set or change due date (supports all date formats)
- `+tag` - Add a tag
- `-tag` - Remove a tag

#### Complete Task

```vim
:Task 1 done    " Mark task ID 1 as completed
```

### Task Display

Tasks are displayed in a floating window with the following columns:
- **ID**: Sequential display ID (used for commands)
- **Urg**: Urgency score (higher = more urgent)
- **Age**: Age of the task (days or years)
- **Due**: Due date (if set)
- **Tags**: Comma-separated list of tags
- **Description**: Task description

Tasks are automatically sorted by urgency (highest first).

### Urgency Calculation

The urgency score is calculated using Taskwarrior-compatible algorithms based on:
- **Next tag**: +15.0 (if task has `+next` tag)
- **Due date**: +12.0 (scaled based on proximity to due date)
- **Active status**: +4.0 (if task is active)
- **Age**: +2.0 (increases over time, max at 365 days)
- **Tags**: +1.0 (if task has any tags)

## Configuration

### Storage Location

Tasks are stored in:
```
~/.local/share/nvim/mikro_taskwarrior/tasks.json
```

You can modify the storage path by editing `lua/mikro_taskwarrior/config.lua`.

### Task Data Structure

Tasks are stored as JSON with the following structure:
```json
[
  {
    "uuid": "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx",
    "description": "Task description",
    "status": "pending",
    "entry": "20241201T120000Z",
    "due": "2024-12-25",
    "tags": ["work", "urgent"]
  }
]
```

## Project Structure

```
Mikro_Taskwarrior/
├── lua/
│   └── mikro_taskwarrior/
│       ├── init.lua              # Plugin entry point
│       ├── config.lua             # Configuration
│       ├── commands.lua           # Command definitions
│       ├── core/
│       │   ├── task.lua           # Task management logic
│       │   ├── storage.lua         # File I/O operations
│       │   └── urgency.lua        # Urgency calculation
│       ├── ui/
│       │   └── window.lua         # Floating window UI
│       └── utils/
│           ├── date.lua           # Date parsing utilities
│           ├── string.lua         # String utilities
│           └── uuid.lua           # UUID generation
└── mikro_taskwarrior.lua          # lazy.nvim plugin spec
```

## Examples

### Basic Workflow

```vim
" Add a task
:Task add Write blog post due:1w +writing

" List all tasks
:Task list

" Add tag to existing task
:Task 1 modify +urgent

" Complete a task
:Task 1 done
```

### Project Management

```vim
" Add project tasks
:Task add Design homepage +project:website +design
:Task add Implement API +project:website +coding due:2w
:Task add Write tests +project:website +testing due:3w

" View all project tasks
:Task +project:website list

" Mark all design tasks as done (requires manual filtering)
:Task +design list  " View, then mark individually
```

### Weekly Planning

```vim
" Plan your week
:Task add Team meeting +work due:monday
:Task add Code review +work +coding due:tuesday
:Task add Documentation +work due:friday

" View this week's work tasks
:Task +work list
```

## Key Bindings

In the task list floating window:
- `q` or `<Esc>` - Close the window

## Requirements

- Neovim 0.7+ (for floating windows and JSON support)
- No external dependencies

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

## Acknowledgments

Inspired by [Taskwarrior](https://taskwarrior.org/), a command-line task management tool.

