/** Validate the login redirect before Strapi decodes it a second time. */
export function safeAdminLoginSearch(search: string): string {
  const params = new URLSearchParams(search);
  const target = params.get('redirectTo');
  if (target === null) return search;
  let decoded: string;
  try {
    decoded = decodeURIComponent(target);
  } catch {
    decoded = '';
  }
  // React Router 6 must only receive a local absolute path here. Browsers treat
  // backslashes and leading control characters differently from route parsers.
  if (
    decoded.startsWith('/') &&
    !decoded.startsWith('//') &&
    !/[\\\u0000-\u0020\u007f]/.test(decoded)
  ) {
    return search;
  }
  params.delete('redirectTo');
  const remaining = params.toString();
  return remaining ? `?${remaining}` : '';
}
