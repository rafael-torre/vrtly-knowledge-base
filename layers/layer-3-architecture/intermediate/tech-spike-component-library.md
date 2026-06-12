---
title: "Tech Spike — @vrtly/component-library (Design System)"
last_updated: 2026-06-12
---

# Tech Spike: @vrtly/component-library (Design System)

## What This Library Does

`@vrtly/component-library` is the shared UI design system for the Vrtly platform. It is consumed by every SPA in the `fmcom-vrtly-fe-monorepo` — the provider-facing CMS, the brand portal, and any future products — as an npm package distributed through AWS CodeArtifact. The library is described internally as the "Spring UI design system" and implements the Vrtly visual language: a monochromatic dark/light palette built around teal (`#52E5DF`) as the brand primary, the Manrope typeface, and a constrained token set for spacing, radius, elevation, and color.

The library serves three distinct consumption surfaces. First, it provides 41 named Vue 3 components exported from `src/main.ts` as an ES module, covering interactive form controls, navigation chrome, content presentation cards, feedback elements, and data display primitives. Second, it exports an icon system in two forms: raw SVG strings (for use inside `v-html` within `el-icon`) and compiled Vue component wrappers, covering 111 icons organized into four namespaces (`arrows-`, `object-`, `social-`, `ui-`). Third, it distributes a standalone SCSS bundle at `dist/scss/` containing the complete token system, reboot baseline, component overrides, and both light and dark theme maps — allowing consuming applications to import styles independently of the JS bundle.

The library is not a pure token layer on top of Element Plus. It is a hybrid: some components are thin prop-forwarding wrappers around Element Plus primitives (VrtlyTag, VrtlyTimeline, VrtlyTooltip, VrtlyCheckbox), while others are self-contained Vue composites that compose multiple Element Plus elements with Vrtly-specific behavior (VrtlyHeader, VrtlyMultiSelect with select-all, AddTo which encodes Vrtly's action/content-list distinction, VrtlyPreview which is a full multi-format media preview subsystem). The SCSS layer aggressively overrides Element Plus CSS variables at the `:root` level, re-mapping the entire `--el-color-*`, `--el-border-radius-*`, `--el-fill-color-*`, and `--el-box-shadow-*` namespaces to Vrtly design tokens, making the visual coupling to Element Plus complete and intentional.

---

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Vue 3 | `^3.3.10` (peer) | Component runtime; Composition API used throughout |
| Element Plus | `^2.9.11` (peer); `^2.11.5` (devDep) | UI primitive library; the library wraps and themes EP extensively |
| `@vueuse/components` | `^12.6.1` (peer) | VueUse composable components; `UseDark` used in UserPopup for dark mode toggle |
| `vue-router` | `^4.2.5` (peer) | Router-link usage in VrtlyNav; required as peer for navigation components |
| `uuid` | `^11.1.0` (runtime dep) | Only runtime dependency; presumably used for key generation in components |
| Vite | `^7.1.7` | Build tool; three separate Vite configs orchestrate three output bundles |
| `@vitejs/plugin-vue` | `^6.0.0` | Vue SFC compilation in Vite |
| `vite-plugin-dts` | `^4.5.4` | TypeScript declaration file generation per-bundle |
| `vite-svg-loader` | `^5.1.0` | SVG import as raw strings (`?raw`) and as Vue components |
| `vite-plugin-static-copy` | `^3.1.2` | Copies `src/scss/` into `dist/scss/` as a distributable stylesheet tree |
| `vue-tsc` | `^2.1.8` | Vue-aware TypeScript compiler; used for `typecheck` and `typebuild` steps |
| TypeScript | `^5.8.3` | Language; ES2024 target, ES2022 module |
| Sass | `^1.83.4` | SCSS compilation; uses `@use`/`@forward` module system throughout |
| Storybook | `^9.0.18` with `@storybook/vue3-vite ^9.1.7` | Component documentation and visual development environment |
| `@chromatic-com/storybook` | `^4.0.1` | Chromatic visual regression integration in Storybook |
| ESLint | `^9.36.0` | Linting; flat config with `typescript-eslint`, `eslint-plugin-vue`, `eslint-plugin-import-x` |
| Prettier | `^3.6.2` | Code formatting |
| `simple-git-hooks` + `lint-staged` | `^2.9.0` / `^15.2.0` | Pre-commit hook: lint and format on staged files |
| `npm-run-all` | `^4.1.5` | Orchestrates parallel/sequential build steps |
| `lodash-es` | (transitive via Element Plus) | Used directly in `MessageBox.ts` for `mergeWith`, `isArray`, `isString` |

---

## Component Inventory

The library exports 41 named symbols from `src/main.ts`. An additional 10 internal sub-components exist inside `src/components/VrtlyPreview/` and are exported selectively. Components are grouped below by functional category.

| Category | Components | Notes |
|---|---|---|
| **Form Controls** | `VrtlyInput`, `VrtlySelect`, `VrtlyMultiSelect`, `VrtlyCheckbox`, `VrtlySwitchToggle`, `VrtlyToggle` | All wrap Element Plus primitives with Vrtly prop interfaces. `VrtlyMultiSelect` adds a "select all" header slot. `VrtlyToggle` is a custom segmented control (no EP base). `VrtlySwitchToggle` wraps `el-switch`. |
| **Buttons & Actions** | `VrtlyButton`, `VrtlyLink`, `VrtlyNavButton`, `VrtlyAddTo` | `VrtlyButton` wraps `el-button`; supports icon-left/right via slots or raw SVG strings. `VrtlyLink` wraps `el-link` with variant (`inline`/`standalone`) and three size tokens. `VrtlyAddTo` is a composite multi-select with distinct primary-action, bulk-action, and content-list sections built on `el-select`. |
| **Navigation** | `VrtlyNav`, `VrtlyNavLogo`, `VrtlyHeader` | `VrtlyNav` renders a `router-link` nav item with icon. `VrtlyHeader` is the full application shell header: logo slot, horizontal menu, avatar dropdown, mobile hamburger toggle. Composes `VrtlyNav`, `VrtlyAvatar`, `VrtlyNavButton`, and `UserPopup`. |
| **Feedback & Overlays** | `VrtlyAlert`, `VrtlyAlertGlobal`, `VrtlyMessage`, `VrtlyMessageBox`, `VrtlyTooltip` | `VrtlyAlert` is a self-contained inline alert with type-mapped icons. `VrtlyAlertGlobal` is a top-of-page scrolling announcement banner with CSS marquee animation. `VrtlyMessage` wraps `ElMessage` to inject Vrtly icons. `VrtlyMessageBox` wraps `ElMessageBox` (alert/confirm/prompt) with custom classes and icon injection. `VrtlyTooltip` is a pass-through of `el-tooltip` that pins the Vrtly popper class. |
| **Data Display** | `VrtlyTable`, `VrtlyTag`, `VrtlyTimeline`, `VrtlyStatisticItem` | `VrtlyTable` wraps `el-table` with a heading/CSV-download header slot. `VrtlyTag` is a minimal `el-tag` wrapper with a `disabled` style class. `VrtlyTimeline` wraps `el-timeline`/`el-timeline-item`. `VrtlyStatisticItem` is a metric card with header, value, formatted change indicator, and tooltip. |
| **Content Cards** | `VrtlyContentCard`, `VrtlyBrandCard`, `VrtlyBrandItemCard`, `VrtlyCollectionCard`, `VrtlyInfoPackCard`, `VrtlyPlaylistCard`, `VrtlyScreenCard`, `VrtlySubscriptionCard`, `VrtlyCompactCard`, `VrtlyConsultCard` | Domain-specific cards encoding platform content types. `VrtlyContentCard` is the most complex: handles transcode state, schedule state, quarantine state, brand badge, QR, ticker, and checkbox multi-select. `VrtlyScreenCard` encodes five tier types (pro/plus/free/brandOnly/locked). |
| **Media & Preview** | `VrtlyPreview`, `PreviewDialog`, `VrtlyImage`, `VrltyVideoThumbnail`, `VrtlyImageUpload` | `VrtlyPreview` is a multi-format viewer supporting VIDEO, IMAGE, ALBUM, PDF, YOUTUBE, SOCIAL_NETWORK_POST. Internal sub-components: `PreviewVideo`, `PreviewImage`, `PreviewAlbum`, `PreviewPdf`, `PreviewYoutube`, `PreviewSocial`, `PreviewControls`, `PreviewPlaceholder`, `LazyImage`. `VrtlyImageUpload` wraps `el-upload` with image-only validation, a 2MB size cap, and loading state. |
| **Layout & Utility** | `VrtlyPageHeader`, `VrtlyListItem`, `VrtlyAvatar`, `VrtlyStepper`, `VrtlyEmptyState`, `UserPopup` | `VrtlyPageHeader` renders breadcrumb, eyebrow, title, and tag strip. `VrtlyListItem` handles drag-reorder, checkbox-select, and default modes. `VrtlyStepper` renders a horizontal/vertical step indicator with completed/active/clickable states. `VrtlyAvatar` wraps `el-avatar` with initials fallback. |

---

## Design Tokens & SCSS Variables

The token system is fully defined in `src/scss/` using the SCSS `@use`/`@forward` module system (no legacy `@import`). The architecture has three layers: SCSS variable definitions, CSS custom property emission at `:root` and `html[theme="dark"]`, and SCSS placeholder classes generated from the token maps for use via `@extend` inside component stylesheets.

### Color Tokens (`_colors.scss`, `themes/_light.scss`, `themes/_dark.scss`)

Colors are the only token set that is theme-aware. The system defines a semantic color model, not a raw palette. All semantic tokens are exposed as CSS custom properties (`--color-<name>`) and their RGB channel decompositions (`--color-rgb-<name>`) to support alpha-compositing without Sass string manipulation.

| Token Category | Token Names | Light Values | Dark Values |
|---|---|---|---|
| Background surfaces | `bg-1` through `bg-4` | White → dark gray (`#FFFFFF` to `#D3D7DA`) | Near-black → dark gray (`#15171A` to `#2F353B`) |
| Foreground text | `fg-1` through `fg-3` | Dark to medium gray (`#15171A` to `#7C8793`) | Light to medium gray (`#DFE2E5` to `#959EA7`) |
| Success | `success-bg-1/2`, `success-fg-1/2/3` | White + green tints, dark greens | Dark bg + bright greens |
| Danger | `danger-bg-1/2`, `danger-fg-1/2/3` | White + orange tint, burnt oranges | Dark bg + bright reds/oranges |
| Info | `info-bg-1/2`, `info-fg-1/2/3` | White + cyan tint, muted teals | Dark bg + teal tones |
| Attention (warning) | `attention-bg-1/2`, `attention-fg-1/2/3` | White + yellow tint, golds | Dark bg + yellows |
| Primary | `primary-bg-1/2/3`, `primary-fg-1` | Dark grays (used as primary action surfaces in light) | Teal `#52E5DF` and derivatives |
| Secondary | `secondary-bg-1/2/3`, `secondary-fg-1` | Alpha overlays (4%/8%/12%) on dark | Alpha overlays on white |
| Brand static | `static-brand-primary`, `static-brand-accent`, `static-brand-black`, `static-brand-white` | `#52E5DF`, `#A5F9B7`, `#15171A`, `#FFFFFF` — same in both themes |
| Overlay/loading | `overlay`, `loading-overlay` | Semi-transparent gray / white | Same values |

The primary/secondary color model inverts between themes: in light mode the primary action color is near-black (`#15171A`) and in dark mode it becomes teal (`#52E5DF`). This is an intentional inversion, not a bug — it means the brand teal is visible against a dark background but would wash out on white.

### Typography Tokens (`_typography.scss`)

| Token | Value |
|---|---|
| Font family | `"Manrope", sans-serif` |
| Font weights | `$font-weight-regular: 400`, `$font-weight-medium: 600`, `$font-weight-bold: 800` |
| Font sizes | 5 levels: `33px / 28px (mobile)`, `20px / 16px`, `16px`, `13px`, `11px` |
| Line heights | 5 levels: `50px / 42px`, `30px / 26px`, `26px`, `22px`, `18px` |
| Semantic classes | `heading-1/2-font`, `body-1/2/3-font`, `label-1/2/3-font`, `link-1/2/3-font` — applied via responsive mixins using CSS container queries (`@container vrtly-container`) |

### Spacing Tokens (`_spacings.scss`)

Scale: `0, 2, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 80, 112` (px). Each step generates SCSS placeholder classes for all eight spacing utilities (`pa`, `px`, `py`, `pl`, `pr`, `pt`, `pb`), margin equivalents, and gap utilities — plus responsive variants (`-small-`) that apply within the container query breakpoint (below 768px). Component sizes: `$size-small: 28px`, `$size-smaller: 40px`, `$size-default: 48px`, `$size-default-large: 52px`, `$size-large: 64px`.

### Border Radius Tokens (`_border-radiuses.scss`)

| Token | Value | Intended use |
|---|---|---|
| `$border-radius-none` | `0` | Textarea, some flat surfaces |
| `$border-radius-compact` | `2px` | Dense UI elements |
| `$border-radius-default` | `4px` | Buttons, dialogs |
| `$border-radius-round` | `999px` | Pills, avatar, default `el-border-radius-base` |
| `$border-radius-container` | `16px` | Panels and inner containers |
| `$border-radius-card` | `20px` | Cards |
| `$border-radius-modal` | `32px` | Modal dialogs |

### Elevation Tokens (`_elevations.scss`)

Four levels defined for both light and dark themes: `surface`, `card`, `dropdown`, `modal`. Exposed as CSS custom properties (`--elevation-<level>`) and mapped directly to Element Plus shadow variables (`--el-box-shadow-*`). The dark theme uses pure black shadows with higher opacity, while the light theme uses `fg-3` RGB at lower opacity.

### Element Plus Variable Overrides (`_element.scss`)

The library overrides approximately 40 Element Plus CSS custom properties at `:root` to remap EP's color, border, fill, and shadow tokens to Vrtly semantic tokens. This is the critical integration file: it uses `@forward "element-plus/theme-chalk/src/common/var.scss" with (...)` to override button Sass variables at compile time (background color, hover states, disabled states, padding horizontal), and then `@use "element-plus/theme-chalk/src/index.scss" as *` to emit all EP styles with the overridden variables baked in. This means the full Element Plus stylesheet is always included in the library's SCSS output — there is no tree-shaking of unused EP components at the CSS level.

### Responsive / Layout Tokens (`_containers.scss`, `_grid.scss`)

Two CSS container query breakpoints: `$breakpoint-sm: 768px` and `$breakpoint-md: 1248px` (md is declared but not used in the public mixin). Responsive behavior relies exclusively on CSS container queries (`@container vrtly-container`) rather than media queries, making components context-responsive rather than viewport-responsive. A 12-column grid system is generated as SCSS placeholders (`%grid`, `%col-1` through `%col-12`), collapsing to 6 columns below 768px.

---

## Build Pipeline & Output Formats

The build is split into three independent Vite configurations, orchestrated by `npm-run-all`:

### Main Library Bundle (`vite.config.mts` → `build:vite`)

- Entry: `src/main.ts`
- Output: `dist/component-library.mjs` (ESM only — `formats: ["es"]`)
- External: only `vue` is externalized; Element Plus, VueUse, and vue-router are NOT externalized, meaning they are bundled into the output
- Type declarations: `vue-tsc --declaration --emitDeclarationOnly` writes `.d.ts` files to `dist/`
- SCSS copy: `vite-plugin-static-copy` copies the entire `src/scss/` tree to `dist/scss/` verbatim
- The `build:vite` script runs `typecheck → build → typebuild` sequentially
- `emptyOutDir: false` is set to prevent the three build steps from overwriting each other

### Icon Raw Strings Bundle (`vite.icons.config.mts` → `build:icons`)

- Entry: `src/assets/icons/index.ts`
- Output: `dist/icons/index.js` (ESM, single file)
- Contains all 111 SVG files exported as raw string constants (via `vite-svg-loader`'s `?raw` transform)
- Used when consuming code injects icon SVGs via `v-html` into `el-icon`

### Icon Vue Components Bundle (`vite.iconComponents.config.mts` → `build:iconComponents`)

- Entry: `src/assets/icons/components.ts`
- Output: `dist/iconComponents/index.js` (ESM, single file)
- Contains all SVGs compiled as Vue components (inlineable as `<component :is="...">`)
- Type declarations: `vite-plugin-dts` outputs to `dist/types/`
- Used when consuming code uses icons as slot content inside `el-icon`

### Package Exports Map (`package.json`)

```json
{
  ".": { "import": "./dist/component-library.mjs", "require": "./dist/component-library.mjs" },
  "./icons": { "import": "./dist/icons/index.js" },
  "./iconComponents": { "import": "./dist/iconComponents/index.js" },
  "./scss/*": "./dist/scss/*"
}
```

The `require` path for the main bundle points to the `.mjs` ESM file — there is no CJS build. Any consumer that requires CJS (e.g., a Jest config using CommonJS transforms without `--experimental-vm-modules`) will fail at resolution. Both `import` and `require` point to the same `.mjs` file, which is not CJS-compatible; this is a known pattern for ESM-only libraries but requires consumer build tooling to handle it correctly.

### CI/CD and Publishing (`bitbucket-pipelines.yml`)

- PRs: lint + typecheck run automatically; Storybook build is manual-trigger
- `main` branch merges: lint + Storybook build runs automatically; Storybook static files are deployed to S3 (`vrtly-storybook` bucket) with a CloudFront invalidation
- Version bumping: three manual-trigger steps on `main` run `npm version patch/minor/major`, commit with `chore: release v%s`, and push a git tag
- Tag events: trigger `npm run build:all` and publish to AWS CodeArtifact (`vrtly-515289352310.d.codeartifact.us-west-2.amazonaws.com/npm/vrtly-component-library/`)

---

## Versioning & Breaking Change Cadence

**Current published version**: `0.8.20`

The major version is `0`, which under semver semantics means the public API is not yet considered stable — any minor or patch bump could theoretically carry breaking changes. In practice the pipeline uses separate `patch`/`minor`/`major` manual steps, suggesting the team does distinguish between change severity.

There is no CHANGELOG file in the repository. Version history is only recoverable from git tags. This creates an operational risk: consuming teams (the monorepo SPAs) cannot determine the nature of changes between their pinned version and any newer published version without diffing source code directly.

**Monorepo pinning**: The `fmcom-vrtly-fe-monorepo` pins `@vrtly/component-library` at `^0.8.20`. The caret range (`^`) at a `0.x.y` version is narrow: it only allows `0.8.z` patches, not minor bumps to `0.9.x`. However, since the package is distributed via a private AWS CodeArtifact registry and does not go through a public npm semver resolution flow, the effective update policy is whatever the consuming team manually runs. Without automated dependency update tooling (Dependabot, Renovate), the monorepo will silently fall behind.

**Breaking-change surface**: Given the library's current structure, the highest-risk sources of breaking changes in a future bump are:

1. Prop interface changes on `VrtlyContentCard` — it encodes platform-specific business logic (`quarantineType`, `transcodingStatus`, `scheduleStatus`) that is tightly coupled to API response shapes
2. Changes to `_element.scss` — any modification to Element Plus variable overrides would change the visual output of all EP-based components globally, without a component-level semver signal
3. Icon renames or removals in `src/assets/icons/index.ts` — consuming apps that import raw SVG strings by name would break silently at runtime (no TypeScript protection on destructured string imports if the export name changes)
4. Storybook-to-API drift — the Storybook stories use static mock data; a story continuing to compile is not a guarantee that the actual component API matches the monorepo's usage

---

## Notable Patterns, Risks & Observations

**1. Element Plus bundled rather than externalized in the main bundle**

`vue` is externalized in `vite.config.mts`, but `element-plus`, `@vueuse/components`, and `vue-router` are declared as `peerDependencies` yet are NOT listed in the Vite `external` array. This means all of Element Plus is bundled into `dist/component-library.mjs`. Any consuming application that also depends on Element Plus will include two copies of the EP runtime: one inside the component library bundle and one in the application's own bundle. This produces duplicate code, inflated bundle size, and potential runtime issues if EP's global state (e.g., message instances, dialog stack) is split across two instances. The peer dependency declaration creates a false expectation that the consumer supplies EP; the build configuration contradicts this.

**2. No CJS output; ESM-only with misleading `require` field**

The `package.json` `exports` map lists a `require` field pointing to `component-library.mjs`. An `.mjs` file is an ES module and cannot be consumed via CommonJS `require()`. Any toolchain that evaluates the `require` condition (e.g., Jest without ESM mode, a Node.js script, a legacy webpack config) will receive the file and fail with a parse error at the `import` keyword. This is a latent integration hazard for any new project that consumes the library in a non-ESM-first environment.

**3. `v-html` with raw SVG strings is an XSS surface**

The icon system relies on passing raw SVG strings (from `index.ts`) into `v-html` directives inside `el-icon`. This pattern is used extensively throughout the component library (VrtlyButton, VrtlyInput, VrtlyNav, VrtlyLink, VrtlyToggle, etc.) and is acknowledged with ESLint disable comments (`// eslint-disable-next-line vue/no-v-html`). If any icon string value were ever sourced from user input or an API response rather than the static import map, this would be an XSS injection vector. The current architecture is safe because icon strings are compile-time constants from the SVG loader, but the pattern requires discipline to not generalize.

**4. SCSS `@extend` across file boundaries creates fragile dependency ordering**

The reboot stylesheet (`_reboot.scss`) uses `@extend` to apply placeholder classes like `%ma-0`, `%body-1-font`, `%heading-1-font` that are defined in `_spacings.scss` and `_typography.scss`. The `index.scss` entry file manages ordering via `@use` statements, but SCSS `@extend` across modules is sensitive to load order — if a file is `@use`d in a different order or from a different entry point, placeholders may not be defined at the point of extension and will throw a compile error. This pattern works in the current single-entry compilation but would be fragile if the SCSS tree were ever split or if individual partials were consumed independently by third parties.

**5. Token system is SCSS-only; no JavaScript token exports**

All design tokens (colors, spacing, radius, elevation, typography) are defined exclusively as SCSS variables and emitted as CSS custom properties. There are no JavaScript or TypeScript token exports. Consuming applications that need token values in JavaScript (e.g., for chart theming with Chart.js/D3, for programmatic color manipulation, or for non-CSS styling in a React Native or Electron context) must either read CSS custom properties at runtime via `getComputedStyle` or duplicate the values manually. This is a common gap in design systems that begins SCSS-first.

**6. Component-level accessibility is shallow**

A review of the component source reveals consistent gaps: `VrtlyToggle` renders `<button>` elements inside a `<div>` without `role="group"` or `aria-label` on the container. `VrtlyListItem`'s drag handle is a `<button>` with only an `alt` attribute on an `<el-icon>` (SVG icons have no inherent accessible label). `VrtlyStepper` renders an `<ol>` with correct semantics but does not set `aria-current="step"` on the active item. `VrtlyEmptyState` is a thin wrapper with no ARIA roles or landmark annotations. `VrtlyAlert` provides icon and message but no `role="alert"` to announce dynamically inserted alerts to screen readers. Element Plus components provide their own ARIA scaffolding, so EP-wrapped components inherit that behavior, but Vrtly-custom composites do not consistently augment it. There is no visible accessibility audit or automated axe integration in the CI pipeline.

**7. Dual icon consumption patterns increase maintenance surface**

Icons are distributed in two parallel forms: raw SVG strings (via `./icons`) and compiled Vue components (via `./iconComponents`). The library itself uses both patterns simultaneously — some components inject icons via `v-html` with raw strings (`VrtlyButton`, `VrtlyNav`, `VrtlyToggle`) and others use the Vue component form via `<slot>` or direct import (`VrtlyAlert`, `VrtlyStepper`, `ContentCard`). The two patterns have different type contracts: the raw string form is `string` with no icon-name type safety, while the component form is a Vue component with proper typing. A consumer must understand both conventions to extend the library correctly. Adding a new icon requires updating both `index.ts` (raw exports) and `components.ts` (Vue component exports) as separate files, and there is no enforcement that both stay in sync.

**8. Version coordination between component library and monorepo is a manual, undocumented process**

There is no integration test pipeline that validates the component library against the monorepo's actual usage. The Bitbucket pipeline builds and deploys Storybook (which uses static mock data) and runs lint/typecheck against the library in isolation. There is no step that installs the freshly-built library into a monorepo test build and validates that all component imports resolve and render correctly. This means a prop rename, a removed export, or a CSS regression can be published to CodeArtifact and only discovered when a developer runs the consuming monorepo locally or a PR build fails.

**9. `MessageBox.ts` imports `lodash-es` directly without it being a declared dependency**

`src/components/MessageBox.ts` imports `{ isArray, isString, mergeWith }` from `lodash-es`. `lodash-es` is not listed in the library's `dependencies` or `devDependencies`. It is available at build time only because Element Plus depends on it transitively, and Vite resolves it from `node_modules`. This is an undeclared dependency: if Element Plus ever removes or renames its `lodash-es` dependency, the component library build will break with a missing module error. The fix is either to add `lodash-es` as an explicit dependency or replace the three utility calls with native JavaScript equivalents.

**10. Storybook coverage is comprehensive but uses static mock data without type enforcement**

Stories exist for all 41 exported components across `stories/Components/` and `stories/Blocks/`. The `Foundation/` section covers Colors, Typography, Spacing, Elevation, Radius, and Icons with MDX documentation pages. However, story data is written as plain object literals with no TypeScript type annotations on the `args`. This means a prop rename in a component will not cause a type error in the story — the story will still compile with stale prop names and Storybook will silently render with missing props. Migrating story args to typed interfaces would close this gap.

**11. Container query responsive strategy requires a `.vrtly-container` wrapper in consuming apps**

Responsive behavior is implemented via CSS container queries on `container-name: vrtly-container`. This means that for mobile-responsive behavior (type scaling, spacing overrides, grid column collapse) to activate, the consuming application must wrap its content in an element that bears the `.vrtly-container` class. If a consuming SPA renders components outside this wrapper, the responsive styles will not activate regardless of viewport width. This constraint is not documented in the README and is not enforced at the component level — it is a hidden integration requirement.

**12. `_element.scss` imports the full Element Plus stylesheet unconditionally**

The `@use "element-plus/theme-chalk/src/index.scss" as *` directive in `_element.scss` imports and compiles every Element Plus component stylesheet into the library's CSS output. Element Plus contains styles for approximately 70+ components. Even if a consuming application only uses 10 library components, the full EP CSS is present. There is no mechanism for consumers to perform CSS tree-shaking on the SCSS output because it is distributed as a pre-compiled SCSS bundle (raw `.scss` files, not processed CSS), and the single `index.scss` entry point includes everything. This adds CSS payload that may never be rendered.

---

## Open Questions

1. **Why is Element Plus not externalized?** The peer dependency declaration promises consumers that EP will be provided externally, but the Vite build bundles it. Is this intentional (to guarantee EP version consistency) or an oversight? The current state means double-bundling EP in every consuming app. What was the decision rationale?

2. **Is there a formal breaking-change policy?** Given the `0.x` major version, any release could technically break consumers. Is there an internal convention about what constitutes a patch, minor, or major bump? Is there a migration guide or release note process when the library publishes a new minor version?

3. **What is the upgrade path to Element Plus `^2.11.5`?** The devDependency uses `^2.11.5` while the peer dependency specifies `^2.9.11`. There are approximately 4 minor versions between these. Were there any Element Plus changes between 2.9.x and 2.11.x that affect the Vrtly overrides in `_element.scss`? Which version is the monorepo currently running?

4. **Are the Vrtly custom fonts (Manrope, CircularStd) loaded by the library or by the consuming app?** The `_typography.scss` defines `font-family: "Manrope", sans-serif`, and `src/assets/` contains `CircularStd-Bold.ttf`, `CircularStd-Book.ttf`, `CircularStd-Medium.ttf` font files. Neither the README nor the SCSS entry point includes `@font-face` rules for Manrope. Do consuming apps need to register the font separately? What is CircularStd used for if Manrope is the defined system font?

5. **What is the intended governance model for adding new icons?** The icon set currently has 111 SVGs organized into four namespaces. Is there a design review process before an icon is added? How are `components.ts` and `index.ts` kept in sync? Is there tooling to auto-generate these index files from the SVG directory, or are they maintained manually?

6. **What is the `uuid` runtime dependency used for?** `uuid` is the only production runtime dependency in `package.json`. A search of the source tree is needed to confirm which component(s) use it and whether it could be replaced with `crypto.randomUUID()` (available in modern browsers) to eliminate the dependency.

7. **Is dark mode fully supported across all 41 components?** The theme system defines a complete dark token map, and `UserPopup` exposes a dark mode toggle via `UseDark`. However, dark mode support is only as complete as each component's SCSS implementation. Is there a matrix of tested dark-mode states per component in Storybook? Are there known components that do not render correctly under `html[theme="dark"]`?

8. **How does the library handle the `VrtlyPreview` sub-components that are not re-exported?** `PreviewVideo`, `PreviewImage`, `PreviewAlbum`, etc. are internal to the VrtlyPreview directory and not listed in `src/main.ts`. If a consuming application needs to customize the preview behavior (e.g., custom PDF rendering), there is no extension point — the entire VrtlyPreview must be replaced. Is this intentional encapsulation or an area for future composability?

9. **What is the Chromatic visual regression integration status?** `@chromatic-com/storybook` is installed as a dev dependency and appears in the Storybook addon list, but there is no Chromatic project token or pipeline step visible in `bitbucket-pipelines.yml`. Is Chromatic actively running against this library, or was the integration scaffolded but never connected to a Chromatic project?

10. **Is there a plan to adopt `<script setup>` with TypeScript `defineProps<T>()` consistently?** The codebase mixes two prop definition patterns: the Options API-style `defineProps({ prop: { type: ..., default: ... } })` (used in most components) and the TypeScript generic form `defineProps<{ prop: string }>()` with `withDefaults` (used in `AddTo.vue`, `CompactCard.vue`, `VrtlyTag.vue`, `VrtlyTimeline.vue`). A consistent TypeScript-first approach would improve type inference for consumers. Is there a migration plan or style guide that governs which pattern to use?
