package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"
)

type Resp struct {
    Project  string `json:"project"`
    Language string `json:"language"`
    TimeUTC  string `json:"time_utc"`
    Note     string `json:"note"`
}

func handler(w http.ResponseWriter, r *http.Request) {
    resp := Resp{
        Project:  "go-hello",
        Language: "go",
        TimeUTC:  time.Now().UTC().Format(time.RFC3339Nano),
        Note:     "If you can see this JSON, Docker build + port mapping works.",
    }
    w.Header().Set("Content-Type", "application/json")
    _ = json.NewEncoder(w).Encode(resp)
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    mux := http.NewServeMux()
    mux.HandleFunc("/", handler)

    srv := &http.Server{
        Addr:              ":" + port,
        Handler:           mux,
        ReadHeaderTimeout: 5 * time.Second,
    }

    log.Printf("go-hello listening on %s", srv.Addr)
    log.Fatal(srv.ListenAndServe())
}
