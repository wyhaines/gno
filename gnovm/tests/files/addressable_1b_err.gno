package main

func main() {
	_ = [1]int{1}[:]
}

// Error:
// main/files/addressable_1b_err.gno:4:6: cannot take address of [(const (1 int))](const-type int){(const (1 int))}

// TypeCheckError:
// main/files/addressable_1b_err.gno:4:6: invalid operation: cannot slice [1]int{…} (value of type [1]int) (value not addressable)
