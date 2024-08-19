# debug go program 
this is simple example on debugging a go program locally and remotley.

it is based on [github.com/kenaqshal/go-debugger]() great tutorial.

## locally
debug directly the program within the vscode (build and run within is done internally)
- run vscode `local debug run`
- put breakpoint in `/test` endpoint
- run `make run-debug-break`

## locally attach to process
debug directly the program within the vscode (build and run within is done internally)
- first build using `make run-app`
- run vscode `local debug attach`
- put breakpoint in `/test` endpoint
- run `make run-debug-break`

NOTE: pay attention to the `preLaunchTask` on the launch.json

## remote locally containerizied
debug build and run the the app in a dockerized environment
- first run `make run-debug-check PLATFORM=linux/$(go env GOARCH)`
- run vscode `remote debug attach`
- put breakpoint in `/test` endpoint
- run `make run-debug-break`
- run `make stop-debug` to drop the container

## remote in kubernatees cluster
debug build, push to docker registry, run conatiner in kubernatees cluster
- set `CONTAINER_REGISTRY` and `REPOSITORY` as env var or directly in `Makefile`
- optinally set `IMAGE_TAG`
- run in cluster
    - option 1 - _run in attached terminal_
        - `make deploy-debug-attached`
            ```
            /go/bin/dlv --listen=:${DEBUG_PORT} --headless=true --log=true --accept-multiclient --api-version=2 exec /go-debugger --continue
            ```
    - option 2 - _run the program detached_
        - `make deploy-debug`
- in another terminal run `make deploy-debug-port-forward`
- run vscode `remote debug attach`
- put breakpoint in `/test` endpoint
- run `make run-debug-break`
- run `make deploy-cleanup` to delete the pod


---

## Notes
- leaving an active breakpoint and detaching the debugger can leave the app hanging as it expect to stop. you should clear the breakpoint before detaching in order to make it continuously running, otherwise connect the debugger again to resume the operation.
- on different platform arch pay attention to PLATFORM env var
- on your project it may needed to use
    ```
                "substitutePath": [
                    {
                        "from": "${workspaceFolder}",
                        "to": "/src"
                    },
                ],
    ```
    or something similiar for the debug configuration