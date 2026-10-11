/** InvTrack design system: plain HTML/CSS equivalents of the Flutter widgets. Every component is a function
 *  that returns an HTML string styled by bundle.css. Load tokens.css, bundle.css, bundle.js; set data-theme
 *  ("light" | "dark") and, for privacy mode, data-privacy="on" on an ancestor. */

type Html = string;
/** A CSS colour, usually a token: "var(--inv-fixed-deposit)". */
type Css = string;

declare namespace InvTrack {
  interface GlassCardProps { radius?: number; padding?: string; flat?: boolean; tap?: boolean; focus?: boolean; label?: string; cls?: string }
  function GlassCard(inner: Html, props?: GlassCardProps): Html;

  type GradientName = 'hero' | 'hero-dark' | 'primary' | 'success' | 'danger' | 'archive' | 'gold';
  function GradientCard(inner: Html, props?: { gradient?: GradientName; glow?: boolean; padding?: string; tap?: boolean }): Html;

  interface ButtonProps {
    variant?: 'gradient' | 'elevated' | 'outlined' | 'text' | 'filled' | 'fab';
    label?: string; icon?: string; iconSize?: number; loading?: boolean; disabled?: boolean;
    /** gradient only; defaults to the light-mode primary #5b4cdb in both themes */
    color?: Css;
  }
  function Button(props: ButtonProps): Html;

  type StatTileProps =
    | { kind?: 'metric'; label: string; value: string; icon?: string; color?: Css; change?: string; positive?: boolean; sensitive?: boolean }
    | { kind: 'quick'; icon: string; label: string; value: string; sub?: string; color: Css; sensitive?: boolean }
    | { kind: 'mini'; label: string; value: string; sub?: string; color?: Css; sensitive?: boolean }
    | { kind: 'net'; label: string; value: string; positive?: boolean; neutral?: boolean; status?: string; returnText?: string }
    | { kind: 'current'; label: string; value?: string; basis: string; action?: string }
    | { kind: 'flows'; out: string; inn: string; count: string }
    | { kind: 'maturity'; date: string; status: string; color?: Css; icon?: string }
    | { kind: 'hero'; label: string; value: string; subtitle?: string };
  function StatTile(props: StatTileProps): Html;

  type GoalStatusKey = 'achieved' | 'on-track' | 'ahead' | 'behind' | 'in-progress' | 'not-started' | 'archived';
  interface GoalCardProps {
    /** 'list' (the default) is the goals list card; 'carousel' is the compact Overview card. */
    kind?: 'list' | 'carousel';
    name: string; emoji?: string; color?: Css; status?: GoalStatusKey;
    /** Already formatted, base currency, e.g. "₹2.5 L of ₹10 L". Masked in privacy mode. */
    progress: string;
    /** Whole percent, 0 to 100. */
    percent?: number;
    /** The footer text, when it is not the status default. It is end-aligned to the card padding and wraps. */
    message?: string;
    /** How many other goals count the same investments: shows "Also in N goals". */
    others?: number;
    privacy?: boolean;
  }
  function GoalCard(props: GoalCardProps): Html;

  type BadgeProps =
    | { kind?: 'change'; value: number; size?: 's' | 'm' | 'l'; filled?: boolean; icon?: boolean; prefix?: string; suffix?: string }
    | { kind: 'status'; label: string; color?: Css; outlined?: boolean }
    | { kind: 'currency'; code: string; rate?: number; target?: string; compact?: boolean }
    | { kind: 'maturity'; label: string; tone?: 'success' | 'warning' | 'accent'; icon?: string }
    | { kind: 'type'; label: string; color: Css }
    | { kind: 'closed' };
  function Badge(props: BadgeProps): Html;

  type ChipProps =
    | { kind?: 'filter'; label: string; count?: number; selected?: boolean; focus?: boolean }
    | { kind: 'type'; label: string; icon: string; color: Css; selected?: boolean; compact?: boolean; focus?: boolean }
    | { kind: 'template'; label: string; emoji: string; color: Css }
    | { kind: 'theme'; label: string; selected?: boolean };
  function Chip(props: ChipProps): Html;

  type EmptyStateProps =
    | { kind?: 'basic'; icon: string; title: string; message: string; actionLabel?: string; actionIcon?: string; compact?: boolean; disc?: [Css, Css] }
    | { kind: 'demo'; title: string; subtitle: string; advertised: string; real: string; caption: string; sr: string }
    | { kind: 'quickstart' | 'sample' | 'error' };
  function EmptyState(props: EmptyStateProps): Html;

  interface TextFieldProps {
    id?: string; label?: string; value?: string; hint?: string; prefixIcon?: string; prefixText?: string;
    error?: string; focus?: boolean; readonly?: boolean; disabled?: boolean; multiline?: boolean; mode?: 'text' | 'decimal' | 'numeric';
  }
  function TextField(props: TextFieldProps): Html;

  type PrivacyMaskProps =
    | { kind: 'toggle'; on?: boolean; size?: number; background?: boolean; color?: Css }
    | { kind: 'amount'; text: string; big?: boolean }
    | { kind: 'blur'; html: Html };
  function PrivacyMask(props: PrivacyMaskProps): Html;

  /** Compact lakh/crore amount; press and hold shows the exact amount (Flutter: long-press and the screen-reader long-press action; Enter and Space are an HTML addition). `amount` is in the base currency. */
  function AmountText(props: { amount: number; symbol?: string; prefix?: string; style?: Record<string, string> }): Html;

  interface SkeletonProps { kind?: 'hero' | 'investment' | 'cashflow' | 'stats' | 'section' | 'fullscreen'; height?: number; message?: string }
  function Skeleton(props?: SkeletonProps): Html;

  interface HeroCardProps {
    amount?: string; returnText?: string; status?: string; positive?: boolean; out?: string; inn?: string;
    xirr?: string; xirrLabel?: string; realisedXirr?: string; note?: string; hint?: string;
    scope?: 'all' | 'realized'; privacy?: boolean; currencyLabel?: string; loading?: boolean;
  }
  function HeroCard(props: HeroCardProps): Html;

  type InvestmentTypeKey = 'p2p-lending' | 'fixed-deposit' | 'bonds' | 'real-estate' | 'private-equity' | 'angel-investing' | 'chit-funds'
    | 'gold' | 'crypto' | 'mutual-funds' | 'stocks' | 'invoice-discounting' | 'financing' | 'other';
  interface InvestmentCardProps {
    type: InvestmentTypeKey; name: string; typeName?: string; closed?: boolean;
    /** Already formatted, base currency. Omit with `empty` or `status`. */
    net?: string; positive?: boolean; badge?: { text: string; positive?: boolean };
    /** Open and awaiting a value ("Awaiting first payout" or "Awaiting current value"): the card shows `invested` and `received` and this chip, with no net, sign or percent. */
    status?: string;
    /** Already formatted, base currency. Shown with `status`. */
    received?: string;
    /** No cash flows yet: a chevron replaces the value column (no amount, no badge). */
    empty?: boolean;
    /** On a narrow card or with large text the label wraps to more lines; it is never cut. */
    maturity?: { tone: 'success' | 'warning' | 'accent'; icon?: string; label: string } | null;
    last: string; entries: string;
    /** Already formatted, base currency. In the strip as "Invested: ", or the main figure with `status`. */
    invested?: string;
    selectionMode?: boolean; selected?: boolean;
  }
  function InvestmentCard(props: InvestmentCardProps): Html;

  interface BottomSheetProps { title: string; icon?: string; reset?: boolean; height?: number; options: { icon: string; label: string; selected?: boolean; isDefault?: boolean; /** icon from the baseline Material set, not the rounded one */ base?: boolean }[] }
  function BottomSheet(props: BottomSheetProps): Html;
  function Dialog(props: { title: string; message?: string; confirm?: string; cancel?: string; destructive?: boolean; variant?: 'confirm' | 'form'; html?: Html; height?: number }): Html;
  function Snackbar(props: { kind?: 'success' | 'error' | 'info' | 'exact'; message: string }): Html;
  function Navigation(props?: { title?: string; actions?: { icon: string; label: string; selected?: boolean }[]; items?: { label: string; icon: string; on: string; outlined?: boolean }[]; active?: number; body?: Html; fab?: boolean }): Html;

  /** A Material icon by ligature name (Google Fonts Material Icons Round by default). */
  function icon(name: string, opts?: { size?: number; color?: Css; family?: 'round' | 'base' | 'outlined'; cls?: string }): Html;
  /** A figure that is replaced by bullets while data-privacy="on". */
  function amount(text: string, opts?: { big?: boolean }): Html;
  /** Light and Dark panes side by side (used by the previews). */
  function panes(render: (theme: 'light' | 'dark') => Html, opts?: { privacy?: boolean; themes?: string[] }): Html;
  /** Attach interactions (privacy toggle, chip selection, clear button, long-press exact amount). */
  function wire(root?: Document | HTMLElement): void;
  function esc(s: unknown): string;

  /** Mirrors lib/core/utils formatters. */
  const fmt: {
    /** formatCurrency: ₹1,00,000 (en_IN grouping by default). */
    inr(n: number, opts?: { decimals?: number; symbol?: string; locale?: 'en_IN' | 'en_US' }): string;
    /** formatCompact: ₹99.95 L, ₹1 Cr; other locales $1.23M. */
    compact(n: number, opts?: { symbol?: string; locale?: 'en_IN' | 'en_US'; decimals?: number }): string;
    /** formatSmart: full below one lakh, compact from one lakh. */
    smart(n: number, opts?: { symbol?: string; locale?: 'en_IN' | 'en_US' }): string;
    percent(v: number, opts?: { decimals?: number; sign?: boolean }): string;
    multiplier(v: number, decimals?: number): string;
    /** Screen-reader text: "1.05 crore rupees". */
    srAmount(n: number, symbol?: string): string;
  };
  const types: Record<InvestmentTypeKey, [name: string, icon: string]>;
}
