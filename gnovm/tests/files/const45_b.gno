package main

type MyStruct struct {
	arr []int
}

const a = len(MyStruct{arr: []int{1, 2}}.arr)

func main() {
	println("ok")
}

// Error:
// main/files/const45_b.gno:7:7: MyStruct<VPBlock(2,0)>{arr<VPField(0,0,arr)>: [](const-type int){(const (1 int)), (const (2 int))}}.arr (variable of type []int) is not constant

// TypeCheckError:
// main/files/const45_b.gno:7:11: len(MyStruct{…}.arr) (value of type int) is not constant
