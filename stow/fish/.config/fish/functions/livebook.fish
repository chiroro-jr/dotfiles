function livebook --description "Start and open Livebook in the browser"
    cd ~/livebook
    docker compose up -d 2>/dev/null
    xdg-open http://localhost:8085
end
