Output docs/brutalist.gif

Set Theme { "name": "Brutalist", "background": "#000000", "foreground": "#FFFFFF", "black": "#000000", "red": "#FFFFFF", "green": "#FFFFFF", "yellow": "#AAAAAA", "blue": "#555555", "purple": "#AAAAAA", "cyan": "#AAAAAA", "white": "#FFFFFF", "brightBlack": "#333333", "brightRed": "#FFFFFF", "brightGreen": "#FFFFFF", "brightYellow": "#CCCCCC", "brightBlue": "#777777", "brightPurple": "#CCCCCC", "brightCyan": "#CCCCCC", "brightWhite": "#FFFFFF", "cursor": "#FFFFFF", "selectionBackground": "#555555" }
Set FontFamily "JetBrains Mono"
Set FontSize 16
Set Width 900
Set Height 550
Set WindowBar Colorful
Set BorderRadius 8
Set Padding 20
Set TypingSpeed 30ms
Set Framerate 24

Hide
Type `export PS1="$(printf '\033[38;2;255;255;255m> \033[0m')"` Enter
Sleep 200ms
Type `printf '----------------------------------------------------------------\n\n\033[1mBRUTALIST\033[0m\nclaude\n\nReady.\n'` Enter
Sleep 500ms
Show

Sleep 2500ms

Type "fix src/index.ts"
Sleep 1200ms
Enter

Hide
Type `printf '\nFixed. 0 errors.\n'` Enter
Sleep 200ms
Show
Sleep 3000ms
