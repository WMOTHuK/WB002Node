export function createErrorResponse(error) {
  const status = error.response?.status || 500;
  const message = error.response?.data?.message || error.message;
  
  return {
    status,
    data: {
      error: 'Failed to fetch goods data',
      details: message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    }
  };
}
