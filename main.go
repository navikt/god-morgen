package main

import (
	"log/slog"
	"net/http"
	"os"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	port := "8080"
	s := newServer(log)

	log.Info("starting server", "port", port)
	if err := http.ListenAndServe(":"+port, s.routes()); err != nil {
		panic(err)
	}
}
