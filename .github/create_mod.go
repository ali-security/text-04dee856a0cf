// Command create_mod produces a Go module zip from a source directory, using
// the same golang.org/x/mod/zip packer the module proxy uses. It is built as
// its own throwaway module outside this checkout so that its go.mod/go.sum
// never land inside the packed tree.
//
// Usage: create_mod <module-path> <version> <dir> <out.zip>
package main

import (
	"fmt"
	"os"

	"golang.org/x/mod/module"
	"golang.org/x/mod/zip"
)

func main() {
	if len(os.Args) != 5 {
		fmt.Fprintln(os.Stderr, "usage: create_mod <module-path> <version> <dir> <out.zip>")
		os.Exit(2)
	}

	mv := module.Version{Path: os.Args[1], Version: os.Args[2]}

	f, err := os.Create(os.Args[4])
	if err != nil {
		fmt.Fprintln(os.Stderr, "create:", err)
		os.Exit(1)
	}

	if err := zip.CreateFromDir(f, mv, os.Args[3]); err != nil {
		fmt.Fprintln(os.Stderr, "CreateFromDir:", err)
		os.Exit(1)
	}

	if err := f.Close(); err != nil {
		fmt.Fprintln(os.Stderr, "close:", err)
		os.Exit(1)
	}

	fmt.Printf("wrote %s for %s@%s\n", os.Args[4], mv.Path, mv.Version)
}
