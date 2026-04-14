# Sunsetting AI Branding Guidelines

This document captures the branding elements from the original Sunsetting AI platform and how they are applied to the OpenClaw fork.

## Brand Identity

**Name**: Sunsetting AI
**Tagline**: Legacy Code Modernization Platform
**Mission**: Comprehensive platform engineered to modernize legacy codebases through advanced AI-powered analysis, strategic planning, and automated transformation.

## Color Palette

### Primary Brand Color

- **Red/Accent**: `#FF4B44` (RGB: 255, 75, 68)
  - Used for primary CTAs, accent elements, logos
  - HSL equivalent: approximately `hsl(2, 100%, 63%)`

### Original Theme CSS Variables (from globals.css)

**Light Mode**:

```css
--background: 0 0% 100%;
--foreground: 222.2 84% 4.9%;
--primary: 222.2 47.4% 11.2%;
--primary-foreground: 210 40% 98%;
--secondary: 210 40% 96%;
--secondary-foreground: 222.2 84% 4.9%;
--muted: 210 40% 96%;
--muted-foreground: 215.4 16.3% 46.9%;
--accent: 210 40% 96%;
--accent-foreground: 222.2 84% 4.9%;
--destructive: 0 84.2% 60.2%;
--destructive-foreground: 210 40% 98%;
--border: 214.3 31.8% 91.4%;
--input: 214.3 31.8% 91.4%;
--ring: 222.2 84% 4.9%;
--radius: 0.5rem;
```

**Dark Mode**:

```css
--background: 222.2 84% 4.9%;
--foreground: 210 40% 98%;
--primary: 210 40% 98%;
--primary-foreground: 222.2 47.4% 11.2%;
--secondary: 217.2 32.6% 17.5%;
--secondary-foreground: 210 40% 98%;
--muted: 217.2 32.6% 17.5%;
--muted-foreground: 215 20.2% 65.1%;
--accent: 217.2 32.6% 17.5%;
--accent-foreground: 210 40% 98%;
--destructive: 0 62.8% 30.6%;
--destructive-foreground: 210 40% 98%;
--border: 217.2 32.6% 17.5%;
--input: 217.2 32.6% 17.5%;
--ring: 212.7 26.8% 83.9%;
```

### Accent Colors

The original platform uses various accent colors for different phases/features:

- Blue gradient: `from-blue-500 to-blue-600`
- Emerald gradient: `from-emerald-500 to-emerald-600`
- Amber gradient: `from-amber-500 to-amber-600`
- Purple gradient: `from-purple-500 to-purple-600`
- And others for different modernization phases

## Typography

### Font Families

From `tailwind.config.ts`:

```typescript
fontFamily: {
  sans: ['var(--font-sans)', ...fontFamily.sans],
  inter: ['var(--font-inter)'],
  'roboto-mono': ['var(--font-roboto-mono)']
}
```

Primary fonts used:

- **Sans-serif**: Inter (variable font)
- **Monospace**: Roboto Mono (for code)

## Logo Assets

### Original Location

`/Users/nicklamb/Desktop/Sunsetting AI/sunsetting-frontend/public/images/`

### Available Logo Files

1. **sunsetting-logo.svg** - Main SVG logo (red/white)
2. **sunsetting-logo-red.svg** - Red variant SVG logo
3. **sunsetting-logo.png** - PNG version (38.7 KB)
4. **placeholder-image.png** - Placeholder asset

### Logo Description

The Sunsetting AI logo consists of:

- A sunset/sun icon made of red squares arranged in a descending pattern
- Represents the "sunsetting" of legacy code
- Primary color: `#FF4B44` (brand red)

## Design System

### Border Radius

- Standard: `0.5rem` (8px)
- Follows Tailwind's default radius system

### Spacing

- Container: centered with `2rem` padding
- Max width: `1400px` for 2xl breakpoint

### Animation/Motion

The original platform includes several custom animations:

- `pulse-subtle`: Subtle pulsing effect
- `confetti`: Celebration animation
- Smooth fade-ins for streaming content
- Message slide-in animations

### Component Style

- Uses shadcn/ui component library
- Tailwind CSS for utility-first styling
- Clean, modern UI with subtle animations
- Focus on readability and accessibility

## Implementation Notes

### Applied to OpenClaw Fork

1. **Logo Assets**: Copied from original to `ui/public/`
2. **Color Variables**: Updated `ui/src/styles/base.css` with Sunsetting red accent
3. **Text References**: Replaced "OpenClaw" with "Sunsetting AI" in UI components
4. **Package Metadata**: Updated descriptions to reflect legacy code modernization mission

### Key Differences from OpenClaw

- **Primary Accent**: Changed from OpenClaw's `#ff5c5c` to Sunsetting's `#FF4B44`
- **Brand Focus**: Shifted from general AI assistant to legacy code modernization
- **Visual Identity**: Replaced OpenClaw branding with Sunsetting sunset logo

## Source Files

Original branding extracted from:

- `/Users/nicklamb/Desktop/Sunsetting AI/sunsetting-frontend/tailwind.config.ts`
- `/Users/nicklamb/Desktop/Sunsetting AI/sunsetting-frontend/styles/globals.css`
- `/Users/nicklamb/Desktop/Sunsetting AI/sunsetting-frontend/public/images/`
- `/Users/nicklamb/Desktop/Sunsetting AI/sunsetting-frontend/package.json`
- `/Users/nicklamb/Desktop/Sunsetting AI/sunsetting-frontend/README.md`
