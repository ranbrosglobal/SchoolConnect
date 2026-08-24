import { GraduationCap, Loader2, X } from 'lucide-react'

export function Spinner({ label = 'Loading…' }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-24 text-ink-soft">
      <Loader2 className="h-7 w-7 animate-spin text-primary" />
      <p className="text-sm">{label}</p>
    </div>
  )
}

export function EmptyState({ title = 'Nothing here yet', hint, action }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 rounded-card border border-dashed border-outline-soft bg-surface px-6 py-16 text-center shadow-card">
      <div className="rounded-full bg-primary-soft p-3 text-primary">
        <GraduationCap className="h-6 w-6" />
      </div>
      <h3 className="text-base font-semibold text-ink">{title}</h3>
      {hint && <p className="max-w-sm text-sm text-ink-soft">{hint}</p>}
      {action}
    </div>
  )
}

export function Card({ className = '', children }) {
  return (
    <div className={`rounded-card border border-outline-soft bg-surface shadow-card ${className}`}>
      {children}
    </div>
  )
}

const BADGE_STYLES = {
  green: 'bg-success-soft text-success',
  red: 'bg-danger-soft text-danger',
  amber: 'bg-warning-soft text-warning',
  blue: 'bg-info-soft text-info',
  neutral: 'bg-surface-low text-ink-soft',
  indigo: 'bg-primary-soft text-primary',
}

export function Badge({ tone = 'neutral', children }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold ${BADGE_STYLES[tone]}`}
    >
      {children}
    </span>
  )
}

export function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-ink">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-ink-soft">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  )
}

export function StatCard({ icon: Icon, label, value, accent = 'indigo', hint }) {
  const accents = {
    indigo: 'bg-primary-soft text-primary',
    green: 'bg-success-soft text-success',
    amber: 'bg-warning-soft text-warning',
    blue: 'bg-info-soft text-info',
  }
  return (
    <Card className="p-5">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-ink-soft">{label}</p>
          <p className="mt-1 text-3xl font-extrabold tracking-tight text-ink">{value}</p>
          {hint && <p className="mt-1 text-xs text-ink-soft">{hint}</p>}
        </div>
        <div className={`rounded-full p-3 ${accents[accent]}`}>
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </Card>
  )
}

const AVATAR_COLORS = [
  'bg-primary-container',
  'bg-success',
  'bg-warning-bright',
  'bg-info',
  'bg-danger',
]

export function Avatar({ name, size = 'md' }) {
  const initials = (name || '?')
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
  const color = AVATAR_COLORS[(name || '').length % AVATAR_COLORS.length]
  const sizes = { sm: 'h-8 w-8 text-xs', md: 'h-10 w-10 text-sm', lg: 'h-14 w-14 text-lg' }
  return (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-full font-bold text-white ${color} ${sizes[size]}`}
    >
      {initials}
    </span>
  )
}

export function Logo({ className = 'h-9 w-9' }) {
  return (
    <span className={`inline-flex items-center justify-center rounded-xl bg-primary text-white ${className}`}>
      <GraduationCap className="h-[60%] w-[60%]" />
    </span>
  )
}

export function Field({ label, children }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">{label}</span>
      {children}
    </label>
  )
}

export const inputClass =
  'w-full rounded-btn border border-outline-soft bg-white px-4 py-2.5 text-sm text-ink placeholder:text-outline focus:border-primary focus:ring-2 focus:ring-primary/25 focus:outline-none transition'

export function PrimaryButton({ children, className = '', ...props }) {
  return (
    <button
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-btn bg-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-container active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-60 ${className}`}
    >
      {children}
    </button>
  )
}

export function SecondaryButton({ children, className = '', ...props }) {
  return (
    <button
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-btn border border-primary/30 bg-white px-4 py-2.5 text-sm font-semibold text-primary transition hover:bg-primary-soft active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-60 ${className}`}
    >
      {children}
    </button>
  )
}

export function Modal({ title, subtitle, onClose, children, wide = false }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-ink/40 backdrop-blur-[2px]" onClick={onClose} />
      <div
        className={`relative w-full ${wide ? 'max-w-2xl' : 'max-w-md'} rounded-card border border-outline-soft bg-surface p-6 shadow-pop`}
      >
        <div className="mb-4 flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold tracking-tight text-ink">{title}</h2>
            {subtitle && <p className="mt-0.5 text-sm text-ink-soft">{subtitle}</p>}
          </div>
          <button
            onClick={onClose}
            aria-label="Close"
            className="rounded-lg p-1.5 text-ink-soft transition hover:bg-surface-low hover:text-ink"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}
