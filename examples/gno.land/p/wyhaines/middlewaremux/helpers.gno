package middlewaremux

func defaultNotFoundHandler(res *ResponseWriter, req *Request) {
	res.Write("404")
}
