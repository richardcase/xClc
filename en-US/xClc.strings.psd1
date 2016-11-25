ConvertFrom-StringData @'
UnexpectedError = An unepected error occured. {1}

# Request responses
ResponseBadRequest = BAD REQUEST. There was something wrong with your query string or body.
ResponseUnauthorised = UNAUTHORIZED. The bearer token is invalid or missing.
ResponseForbidden = FORBIDDEN. Request violates the security demands.
ResponseNotFound = NOT FOUND. The URL points to a non-existent resource. Url: {0}
ResponseServerError = INTERNAL SERVER ERROR. There was an error on the server. Try again.
'@