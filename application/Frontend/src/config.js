// Keep browser requests on the same origin.  Vite forwards `/api` to the
// backend service, so the browser never needs to resolve a container hostname
// or incorrectly call its own `localhost:5000`.
export const API_BASE_URL = import.meta.env.VITE_API_URL || '';
