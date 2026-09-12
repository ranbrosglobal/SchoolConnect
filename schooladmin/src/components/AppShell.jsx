import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  BookOpen,
  CalendarDays,
  GraduationCap,
  LayoutDashboard,
  LogOut,
  Menu,
  Settings,
  Users,
  X,
} from 'lucide-react'
import { useAuth } from '../lib/auth'
import { useInactivityLogout } from '../lib/useInactivityLogout'
import { Avatar, Badge, Logo } from './ui'

const NAV = [
  { to: '/', label: 'Overview', icon: LayoutDashboard, end: true },
  { to: '/teachers', label: 'Teachers', icon: GraduationCap },
  { to: '/classes', label: 'Classes', icon: BookOpen },
  { to: '/timetable', label: 'Timetable', icon: CalendarDays },
  { to: '/students', label: 'Students', icon: Users },
  { to: '/settings', label: 'Settings', icon: Settings },
]

function SidebarContent({ onNavigate }) {
  const { user, logout } = useAuth()
  const navigate = useNavigate()

  async function handleLogout() {
    await logout()
    navigate('/login', { replace: true })
  }

  return (
    <div className="flex h-full flex-col">
      {/* Brand */}
      <div className="flex items-center gap-3 px-5 pb-6 pt-5">
        <Logo />
        <div>
          <p className="text-base font-extrabold tracking-tight text-ink">School Connect</p>
          <p className="text-xs text-ink-soft">School Admin Console</p>
        </div>
        <button
          className="ml-auto rounded-lg p-1.5 text-ink-soft hover:bg-surface-low lg:hidden"
          onClick={onNavigate}
          aria-label="Close menu"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-1 overflow-y-auto px-3">
        {NAV.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            onClick={onNavigate}
            className={({ isActive }) =>
              `group flex items-center gap-3 rounded-btn px-3 py-2.5 text-sm font-semibold transition ${
                isActive
                  ? 'bg-primary text-white shadow-card'
                  : 'text-ink-soft hover:bg-surface-low hover:text-ink'
              }`
            }
          >
            <Icon className="h-[18px] w-[18px]" />
            {label}
          </NavLink>
        ))}
      </nav>

      {/* User card */}
      <div className="border-t border-outline-soft/60 p-4">
        <div className="flex items-center gap-3">
          <Avatar name={user.full_name} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-ink">{user.full_name}</p>
            <p className="truncate text-xs text-ink-soft">{user.email}</p>
            <div className="mt-1">
              <Badge tone="amber">School Admin</Badge>
            </div>
          </div>
          <button
            onClick={handleLogout}
            title="Sign out"
            className="rounded-lg p-2 text-ink-soft transition hover:bg-danger-soft hover:text-danger"
          >
            <LogOut className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  )
}

export default function AppShell() {
  const { user } = useAuth()
  const { showWarning, resetTimer } = useInactivityLogout()
  const [menuOpen, setMenuOpen] = useState(false)

  return (
    <div className="flex min-h-screen bg-background">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 border-r border-outline-soft/60 bg-surface lg:block">
        <SidebarContent onNavigate={() => {}} />
      </aside>

      {/* Mobile sidebar */}
      {menuOpen && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-ink/40" onClick={() => setMenuOpen(false)} />
          <aside className="absolute inset-y-0 left-0 w-64 bg-surface shadow-pop">
            <SidebarContent onNavigate={() => setMenuOpen(false)} />
          </aside>
        </div>
      )}

      {/* Main column */}
      <div className="flex min-h-screen w-full flex-col lg:pl-60">
        {/* Top bar */}
        <header className="sticky top-0 z-20 border-b border-outline-soft/60 bg-background/80 backdrop-blur">
          <div className="flex items-center gap-3 px-4 py-3 sm:px-8">
            <button
              className="rounded-lg p-2 text-ink-soft hover:bg-surface-low lg:hidden"
              onClick={() => setMenuOpen(true)}
              aria-label="Open menu"
            >
              <Menu className="h-5 w-5" />
            </button>
            <div className="flex min-w-0 flex-1 items-center gap-2">
              <Badge tone="amber">{user.school_name}</Badge>
            </div>

          </div>
        </header>

        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-8">
          {showWarning && (
            <div className="mb-4 flex items-center justify-between rounded-btn border border-warning/30 bg-warning-soft px-4 py-3 text-sm">
              <span className="font-medium text-warning">You will be logged out in less than 1 minute due to inactivity.</span>
              <button onClick={resetTimer} className="ml-4 rounded-btn bg-warning px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-warning/90">
                Stay logged in
              </button>
            </div>
          )}
          <Outlet />
        </main>
      </div>
    </div>
  )
}
