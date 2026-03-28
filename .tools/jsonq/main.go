// jsonq — minimal jq-compatible CLI for platforms without jq installed.
// Uses gojq for full jq query compatibility.
// Build: go build -o ../../tools/bin/jq .
// Usage: jsonq [-r] <filter> [file]
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	"github.com/itchyny/gojq"
)

func main() {
	rawOutput := false
	filter := ""
	inputFile := ""

	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-r":
			rawOutput = true
		default:
			if filter == "" {
				filter = args[i]
			} else {
				inputFile = args[i]
			}
		}
	}

	if filter == "" {
		fmt.Fprintln(os.Stderr, "usage: jsonq [-r] <filter> [file]")
		os.Exit(1)
	}

	var reader io.Reader = os.Stdin
	if inputFile != "" {
		f, err := os.Open(inputFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "jsonq: %v\n", err)
			os.Exit(1)
		}
		defer f.Close()
		reader = f
	}

	data, err := io.ReadAll(reader)
	if err != nil {
		fmt.Fprintf(os.Stderr, "jsonq: read error: %v\n", err)
		os.Exit(1)
	}

	var input interface{}
	if err := json.Unmarshal(data, &input); err != nil {
		fmt.Fprintf(os.Stderr, "jsonq: invalid JSON: %v\n", err)
		os.Exit(1)
	}

	query, err := gojq.Parse(filter)
	if err != nil {
		fmt.Fprintf(os.Stderr, "jsonq: parse error: %v\n", err)
		os.Exit(1)
	}

	iter := query.Run(input)
	exitCode := 0
	for {
		v, ok := iter.Next()
		if !ok {
			break
		}
		if err, ok := v.(error); ok {
			fmt.Fprintf(os.Stderr, "jsonq: %v\n", err)
			exitCode = 5
			continue
		}
		if rawOutput {
			if s, ok := v.(string); ok {
				fmt.Println(s)
				continue
			}
		}
		out, _ := json.Marshal(v)
		fmt.Println(string(out))
	}
	os.Exit(exitCode)
}
