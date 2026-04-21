# Contributing

Want to add a skin? Great. Here's how.

## Creating a Skin

1. Copy `template.yaml` to `skins/<your-skin-name>.yaml`
2. Set `name:` to match the filename (without `.yaml`)
3. Customize the keys you want — missing values inherit from `default.yaml`
4. Optionally create a matching `personalities/<your-skin-name>.md` for Claude's voice
5. Test it: `./engine/activate.sh your-skin-name`

## Guidelines

- **Keep it tasteful.** Skins are visual themes, not pranks.
- **Test your terminal colors.** Not all terminals support OSC sequences the same way. Test on at least iTerm2 or Kitty.
- **Banner art should fit in 80 columns.** Braille art is great, block characters work too.
- **Personality files are optional but encouraged.** Keep them subtle — seasoning, not the main course.
- **ANSI escape codes in banners** use `\033[38;2;R;G;Bm` for 24-bit color. End each line with `\033[0m`.

## Submitting

1. Fork the repo
2. Add your skin files
3. Open a PR with a screenshot of the skin active in your terminal

## Schema

See [SCHEMA.md](SCHEMA.md) for the full reference of all configurable keys.
