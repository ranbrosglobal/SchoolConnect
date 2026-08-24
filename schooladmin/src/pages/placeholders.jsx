import { Link } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { EmptyState, PageHeader } from '../components/ui'

export function PlaceholderPage({ title, phase, description }) {
  return (
    <>
      <PageHeader title={title} />
      <EmptyState
        title={`Coming in ${phase}`}
        hint={description}
        action={
          <Link
            to="/"
            className="mt-3 inline-flex items-center gap-2 rounded-btn bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-primary-container"
          >
            Back to overview
          </Link>
        }
      />
    </>
  )
}

export function NotFoundPage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-background px-6 text-center">

      <h1 className="text-2xl font-extrabold tracking-tight text-ink">Page not found</h1>
      <p className="text-sm text-ink-soft">The page you're looking for doesn't exist or was moved.</p>
      <Link
        to="/"
        className="mt-2 inline-flex items-center gap-2 rounded-btn bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-primary-container"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to overview
      </Link>
    </div>
  )
}
