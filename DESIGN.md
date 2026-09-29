---
name: Rayando Festive Gaming System
colors:
  surface: '#0a112c'
  surface-dim: '#0a112c'
  surface-bright: '#313854'
  surface-container-lowest: '#050c27'
  surface-container-low: '#131a35'
  surface-container: '#171e39'
  surface-container-high: '#222844'
  surface-container-highest: '#2d3350'
  on-surface: '#dde1ff'
  on-surface-variant: '#d4c5ab'
  inverse-surface: '#dde1ff'
  inverse-on-surface: '#282f4b'
  outline: '#9c8f78'
  outline-variant: '#4f4632'
  surface-tint: '#fabd00'
  primary: '#ffe4af'
  on-primary: '#3f2e00'
  primary-container: '#ffc107'
  on-primary-container: '#6d5100'
  inverse-primary: '#785900'
  secondary: '#ffb5a0'
  on-secondary: '#5f1500'
  secondary-container: '#d73b00'
  on-secondary-container: '#fffbff'
  tertiary: '#aef2ff'
  on-tertiary: '#00363d'
  tertiary-container: '#00dff8'
  on-tertiary-container: '#005e6a'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdf9e'
  primary-fixed-dim: '#fabd00'
  on-primary-fixed: '#261a00'
  on-primary-fixed-variant: '#5b4300'
  secondary-fixed: '#ffdbd1'
  secondary-fixed-dim: '#ffb5a0'
  on-secondary-fixed: '#3b0900'
  on-secondary-fixed-variant: '#862200'
  tertiary-fixed: '#9cf0ff'
  tertiary-fixed-dim: '#00daf3'
  on-tertiary-fixed: '#001f24'
  on-tertiary-fixed-variant: '#004f58'
  background: '#0a112c'
  on-background: '#dde1ff'
  surface-variant: '#2d3350'
typography:
  headline-xl:
    fontFamily: Rubik
    fontSize: 40px
    fontWeight: '900'
    lineHeight: 48px
  headline-xl-mobile:
    fontFamily: Rubik
    fontSize: 28px
    fontWeight: '900'
    lineHeight: 34px
  headline-lg:
    fontFamily: Rubik
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Rubik
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 30px
  headline-md:
    fontFamily: Rubik
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Rubik
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Nunito Sans
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 26px
  body-md:
    fontFamily: Nunito Sans
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 22px
  body-sm:
    fontFamily: Nunito Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-lg:
    fontFamily: Rubik
    fontSize: 16px
    fontWeight: '800'
    lineHeight: 20px
  label-md:
    fontFamily: Rubik
    fontSize: 13px
    fontWeight: '700'
    lineHeight: 16px
  label-sm:
    fontFamily: Rubik
    fontSize: 11px
    fontWeight: '800'
    lineHeight: 14px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-lg: 1.5rem
  margin: 1rem
  margin-md: 1.5rem
  margin-lg: 2.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

This design system channels the warmth, lightning-fast banter, and vibrant pop culture of a social Venezuelan drawing showdown. Built for casual, cross-platform multiplayer sessions, the visual identity fuses modern arcade responsiveness with tactile, comic-inspired game elements. It balances immediate legibility during fast-paced 60-second drawing rounds with an energetic, carnival-infused aesthetic.

The style is **Tactile Neopop**:
- Chunky, pill-sculpted interaction surfaces that simulate physical push-buttons with deep underside shadows.
- Vibrant, tropical high-contrast accents grounded against deep navy canvases to prevent visual fatigue during marathon sessions.
- Playful geometry featuring oversized radiuses, bouncy micro-interactions, punchy comic badges, and clean gamer telemetry (timers, point streak badges, and active palette docks).

## Colors

The palette establishes an electric arena feel by resting intensely saturated Caribbean primaries against tiered, oceanic midnight depths.

### Color Tokens & Roles
- **Canvas Base (`#0B1124`)**: Deepest midnight blue. Applied to fullscreen underlays, app bars, and viewport frames.
- **Surface Elevation 1 (`#141B36`)**: Core gaming background for panels, chat docks, and player drawer rails.
- **Surface Elevation 2 (`#1E284E`)**: Active cards, canvas drawing borders, toolbars, and modal containers.
- **Surface Elevation 3 (`#293664`)**: Hover states, pill tracks, and inactive utility wells.
- **Primary Accent (`#FFC107`)**: Sunny golden yellow. Reserved for drawing leader callouts, primary action buttons, first-place podium finishes, and timer warnings under 15 seconds.
- **Secondary Accent (`#FF5722`)**: Warm electric papaya orange. Signals turn alerts, brush-size sliders, streak multipliers, and urgent player prompts.
- **Tertiary Accent (`#00E5FF`)**: Electric cyan. Highlights chat mentions, room codes, current tools, and collaborative indicators.
- **Success / Score Green (`#00E676` / `#00C853`)**: High-luminance emerald. Triggers exclusively when a player guesses the word correctly, gains score points, or reaches an active match lobby.
- **Error / Penalty Red (`#FF1744`)**: Crisp crimson for kick votes, disconnects, and report actions.
- **Text On Dark (High Contrast)**: `#FFFFFF` (Headings, primary button text, player names).
- **Text On Dark (Muted)**: `#8E9ECA` (Timestamps, metadata, chat system labels).

## Typography

The typographic hierarchy pairs the thick, playful geometric geometry of **Rubik** for display counters, timers, and badges with the friendly, ultra-readable rounded grotesque curves of **Nunito Sans** for stream-style chat feeds and options.

- All display headlines leverage ultra-bold weights (`800` or `900`) with tight tracking (`-0.02em`) to produce punchy comic impact.
- Live in-game chat prioritizes `body-md` with `600` weight to guarantee instant readability against dark background surfaces during animated chat rolls.
- Scores, timers, and button labels strictly utilize `Rubik` in uppercase or heavy titling for an unmistakable arcade posture.

## Layout & Spacing

The layout is arranged around a rigid, arcade-focused **3-pane modular grid** on desktop, converting into stacked contextual docks on mobile devices.

### Grid & Breakpoints
- **Desktop (1024px and up)**: 3-column game stadium. 
  - Left rail (240px to 280px fixed): Leaderboard, player avatars, and status icons.
  - Center stage (Flex 1): Drawing whiteboard, upper word/hint HUD, and lower drawing toolbox.
  - Right rail (320px to 360px fixed): Live guess stream, system notifications, and chat input dock.
- **Tablet (768px - 1023px)**: 2-column layout. Leaderboard condenses into a horizontal player ribbon above the canvas; Chat and Canvas sit side-by-side.
- **Mobile (< 768px)**: Single-column vertically stacked view. The drawing canvas commands the top 55% of viewport height; player pills and an expandable guess/chat drawer occupy the lower half.

Spacing uses a dynamic 4px/8px scale designed to keep toolbars compact while allowing large hit targets for finger-painting and rapid button taps.

## Elevation & Depth

Visual depth avoids realistic lighting in favor of a playful 2.5D **Arcade Bevel & Drop** aesthetic.

- **Level 0 (Floor)**: Canvas background `#0B1124` with an optional subtle SVG grid or polka-dot matrix tinted at 3% `#00E5FF`.
- **Level 1 (Dock & Shelves)**: `#141B36` containers framed with a crisp 2px border in `#293664` to delineate zones.
- **Level 2 (Interactive Cards & Whiteboard)**: `#1E284E` surfaces elevated with a zero-blur solid offset shadow: `box-shadow: 0px 4px 0px #090D1C`.
- **Level 3 (Tactile Game Buttons & Badges)**:
  - Yellow primary button: Base surface `#FFC107`, solid inset highlight `inset 0px 2px 0px rgba(255, 255, 255, 0.4)`, bottom drop shelf `box-shadow: 0px 5px 0px #C79100`.
  - On `:active`, the element translates down 3px with shadow reduced to `0px 2px 0px #C79100`, creating physical button actuation.
- **Modals & Overlays**: Surface `#1E284E` with an extra-wide ambient halo `0px 20px 40px rgba(0, 0, 0, 0.6)` and an outer 3px solid border in `#FFC107`.

## Shapes

The interface embraces a hyper-rounded, friendly, non-threatening geometry (`roundedness: 3`).

- All primary buttons, text inputs, user chips, round timers, and tool selectors feature fully pill-shaped contours (`border-radius: 9999px` or minimum `2rem`).
- Drawing canvas containers, player rank scorecards, and modal sheets use generous `1.5rem` to `2rem` rounded corners to maintain a friendly toy-like charm.
- Tool swatches (color palette picker) use perfect circles with thick active indicator rings.

## Components

### Buttons
- **Primary Pill (Play, Guess, Ready)**: Background `#FFC107`, text `#0B1124`, weight `800`. 3D bottom bevel of `4px` in `#C79100`. On hover, brightness shifts `105%`; on click, physically depresses `3px`.
- **Secondary Action (Clear, Undo, Skip)**: Background `#1E284E`, text `#FFFFFF`, border `2px solid #293664`. Bottom bevel `4px` in `#10162A`.
- **Destructive Pill (Leave, Kick, Report)**: Background `#FF1744`, text `#FFFFFF`, bottom bevel `4px` in `#B71C1C`.

### Input Fields & Guess Bar
- Fully rounded pill input with surface `#0B1124` and text `#FFFFFF`.
- Permanent `2px solid #293664` border that transitions instantly to `#00E5FF` with a cyan outer glow (`0 0 12px rgba(0, 229, 255, 0.3)`) when focused.
- Integrated right-aligned submit icon button nested inside the pill wrapper.

### Chat & Guess Stream
- Feed displays in reverse-scroll order.
- **Normal Guess**: `#8E9ECA` sender label, `#FFFFFF` guess text.
- **Correct Guess Banner**: Full pill container tinted in `#00E676` with bold `#0B1124` text reading: *"¡[Jugador] acertó la palabra!"* accompanied by floating mini-sparkle glyphs.
- **Close Guess Warning**: `#FF5722` text indicating *"¡Estás muy cerca!"*.

### Player Leaderboard Cards
- Horizontal pill cards inside `#141B36`.
- Left: Circular avatar frame with colored level rings (`#00E5FF`, `#FFC107`).
- Center: Username in `label-lg` (`#FFFFFF`), subtitle showing current score (`#8E9ECA`).
- Right: Position badge (`1°`, `2°`, `3°`) painted in metallic golds and bronzes.
- Active Drawer state pulses with a rotating dashed accent border in `#FFC107`.

### Canvas & Drawing Toolkit Dock
- **Canvas Whiteboard**: Crisp white `#FFFFFF` surface with heavy rounded corners (`1.5rem`) inset into a deep `#141B36` cradle.
- **Color Bar**: Horizontal flex pill docking 12 to 16 vibrant circular color wells (`32px` diameter). Active color pops upward by `4px` with a pure white double ring outline.
- **Brush Size Slider**: Custom thick papaya-orange (`#FF5722`) pill thumb sliding across a midnight blue rail.