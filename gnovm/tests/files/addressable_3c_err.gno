package main

type MyStruct struct {
	Mp *int
}

func makeT() MyStruct {
	x := 10
	return MyStruct{Mp: &x}
}

func main() {
	_ = &makeT().Mp
}

// Error:
// main/files/addressable_3c_err.gno:13:6: cannot take address of makeT<VPBlock(3,1)>().Mp

// TypeCheckError:
// main/files/addressable_3c_err.gno:13:7: invalid operation: cannot take address of makeT().Mp (value of type *int)
