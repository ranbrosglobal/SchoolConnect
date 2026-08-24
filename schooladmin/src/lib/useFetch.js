import { useCallback, useEffect, useRef, useState } from 'react'

/*
 * Minimal data-fetching hook.
 *   const { data, loading, error, reload } = useFetch(() => api.getTeachers(), [school])
 */
export function useFetch(loader, deps = []) {
  const loaderRef = useRef(loader)
  loaderRef.current = loader

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const reload = useCallback(() => {
    let alive = true
    setLoading(true)
    setError(null)
    loaderRef.current()
      .then((d) => {
        if (alive) setData(d)
      })
      .catch((e) => {
        if (alive) setError(e?.message || 'Something went wrong')
      })
      .finally(() => {
        if (alive) setLoading(false)
      })
    return () => {
      alive = false
    }
  }, [])

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => reload(), deps)

  return { data, loading, error, reload }
}
