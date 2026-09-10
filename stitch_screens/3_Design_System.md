---
name: Professional Notebook
colors:
  surface: '#f8f9fc'
  surface-dim: '#d9dadd'
  surface-bright: '#f8f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3f6'
  surface-container: '#edeef1'
  surface-container-high: '#e7e8eb'
  surface-container-highest: '#e1e2e5'
  on-surface: '#191c1e'
  on-surface-variant: '#454653'
  inverse-surface: '#2e3133'
  inverse-on-surface: '#f0f1f4'
  outline: '#757685'
  outline-variant: '#c5c5d6'
  surface-tint: '#3f52c8'
  primary: '#3145bb'
  on-primary: '#ffffff'
  primary-container: '#4c5fd5'
  on-primary-container: '#eaeaff'
  inverse-primary: '#bbc3ff'
  secondary: '#815600'
  on-secondary: '#ffffff'
  secondary-container: '#fdaf1e'
  on-secondary-container: '#6a4600'
  tertiary: '#005f40'
  on-tertiary: '#ffffff'
  tertiary-container: '#007a53'
  on-tertiary-container: '#a3ffd0'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dee0ff'
  primary-fixed-dim: '#bbc3ff'
  on-primary-fixed: '#000e5e'
  on-primary-fixed-variant: '#2338af'
  secondary-fixed: '#ffddb1'
  secondary-fixed-dim: '#ffba4b'
  on-secondary-fixed: '#291800'
  on-secondary-fixed-variant: '#624000'
  tertiary-fixed: '#7ff9c1'
  tertiary-fixed-dim: '#61dca6'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9fc'
  on-background: '#191c1e'
  surface-variant: '#e1e2e5'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  doodle-note:
    fontFamily: Kalam
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style
The design system for this product balances the structured reliability of academic management with the expressive creativity of student life. It targets a multi-generational user base—from tech-savvy students to busy administrators—by utilizing a **Modern Corporate** foundation infused with **Hand-drawn Accents**.

The aesthetic mimics a high-quality physical notebook: clean, high-density layouts represent the "printed" structure, while occasional vector "doodles" (stars, underlines, and arrows) represent the human element of learning. The emotional response should be one of organized clarity punctuated by moments of encouragement.

## Colors
The palette uses **Deep Indigo** as the primary anchor for authority and trust. **Warm Amber** acts as a high-visibility accent for calls to action and highlights. 

A specific semantic logic is applied to attendance states:
- **Emerald:** Presence and success.
- **Coral Red:** Absence and critical alerts.
- **Sky Blue:** Approved leave and informational notices.

Role-based identity is reinforced through header gradients:
- **Student:** Deep Indigo to Sky Blue.
- **Teacher:** Deep Indigo to Emerald.
- **Admin:** Deep Indigo to a deep purple tint.

## Typography
The typographic hierarchy relies on **Plus Jakarta Sans** for all functional UI elements to ensure maximum legibility and a modern, geometric feel. 

The **Kalam** font is used exclusively for "hand-written" annotations. These should never be used for critical data, but rather for celebratory feedback (e.g., "Great job!" next to a grade) or marginalia that directs attention to specific features. Use `doodle-note` sparingly to maintain the professional aspect of the "Professional Notebook" style.

## Layout & Spacing
The layout follows a **Fluid Grid** model with high density to accommodate large amounts of student data. 

- **Desktop:** 12-column grid with 24px gutters. Content is often organized into "sheets" resembling notebook pages.
- **Mobile:** 4-column grid with 16px margins. Bottom navigation is mandatory for accessibility.

Vertical rhythm is strictly maintained using 8px increments (`xs`, `sm`, `md`) to keep the dense information readable. Use generous white space between "sections" but tight padding within cards to maximize information density.

## Elevation & Depth
This design system uses **Tonal Layering** combined with **Low-contrast Outlines**. 

Surfaces are primarily defined by hairline borders (1px, color: `#E2E8F0`) rather than heavy shadows. 
- **Level 0 (Background):** #F8F9FC.
- **Level 1 (Cards/Sheets):** White (#FFFFFF) with a 1px hairline border and a very soft, diffused shadow (0px 4px 12px rgba(35, 38, 53, 0.05)).
- **Level 2 (Modals/Popovers):** White with a more pronounced shadow (0px 8px 24px rgba(35, 38, 53, 0.1)).

Interactive elements like buttons use a subtle inner-glow on hover to simulate the tactile feel of a high-quality physical tool.

## Shapes
The primary shape language is **Rounded**. Large containers and cards use a specific **18px radius** to create a soft, approachable container for the data. 

Secondary elements like buttons and input fields follow the `rounded-lg` (16px) standard. Status badges and progress rings are fully circular. Hand-drawn accents (doodles) should use a variable stroke width (roughly 2px) to maintain a "marker on paper" aesthetic, distinct from the pixel-perfect lines of the UI structure.

## Components

### Buttons & Controls
- **Primary Button:** Solid Deep Indigo with white text, 16px border-radius.
- **Secondary Button:** White background, Deep Indigo border (1px), Deep Indigo text.
- **Doodle Accents:** Occasionally, a "squiggle" underline or a hand-drawn arrow may appear near a primary CTA to draw the eye.

### Cards
- **Attendance Card:** 18px radius, white background, hairline border. Contains a **Circular Progress Ring** on the left and primary data on the right. 
- **Scribble Borders:** Use dashed "hand-drawn" borders for empty states or optional "add" slots.

### Status Badges
- Small capsules with 10% opacity backgrounds of their semantic color (e.g., 10% Emerald for "Present").
- Include a 6px solid dot and 2px stroke line-art icons.

### Inputs
- **Field Style:** Background #FFFFFF, 1px border #E2E8F0. On focus, the border changes to Deep Indigo with a 2px soft outer glow.
- **Labels:** Use `label-caps` for field headers to provide clear hierarchy in dense forms.

### Navigation
- **Bottom Bar:** Thin 2px stroke line-art icons. Active states use the Primary color with a hand-drawn "circle" or "dot" doodle underneath the icon to indicate the current tab.