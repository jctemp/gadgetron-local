#!/bin/sh

IMAGE_NAME="gadgetron-client"
CONTAINER_NAME="gadgetron-client-instance"
CONTAINER_CMD="podman"
DATA_DIR="$(pwd)/data"

DEFAULT_HOST="localhost"
DEFAULT_PORT="27001"
DEFAULT_CONFIG="default.xml"

show_help() {
    echo "Gadgetron ISMRMRD Client Wrapper"
    echo "Usage: $0 [options] [-- pass-through-arguments]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -r, --rebuild           Force rebuild of the container image"
    echo "  -k, --keep              Keep the container after execution"
    echo "  -c, --copy-result       Copy result back to working directory"
    echo "  -b, --backend <name>    Select container backend (podman|docker)"
    echo ""
    echo "Client Options:"
    echo "  --host <hostname>       Gadgetron server hostname (default: $DEFAULT_HOST)"
    echo "  --port <number>         Gadgetron server port (default: $DEFAULT_PORT)"
    echo "  --input <file>          Input data file (required)"
    echo "  --output <file>         Output data file (default: based on input filename)"
    echo "  --config <file>         Configuration file (default: $DEFAULT_CONFIG)"
    echo "  --verbose               Enable verbose output"
    echo ""
    echo "Advanced:"
    echo "  --                      Pass all subsequent arguments directly to client"
    exit 0
}

image_exists() {
    if [ "$CONTAINER_CMD" = "podman" ]; then
        $CONTAINER_CMD image exists "$IMAGE_NAME" >/dev/null 2>&1
    else
        $CONTAINER_CMD image inspect "$IMAGE_NAME" >/dev/null 2>&1
    fi
    return $?
}

build_image() {
    echo "Building container image $IMAGE_NAME..."
    $CONTAINER_CMD build -t "$IMAGE_NAME" -f "$(dirname "$0")/client.Dockerfile" .
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "Failed to build container image" >&2
        return 1
    fi
    return 0
}

prepare_data_dir() {
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    echo "Using data directory: $DATA_DIR"
}

copy_input_file() {
    input_file="$1"
    
    if [ ! -r "$input_file" ]; then
        echo "Error: Cannot read input file: $input_file" >&2
        return 1
    fi
    
    cp "$input_file" "$DATA_DIR/"
    chmod 644 "$DATA_DIR/$(basename "$input_file")"
    echo "Copied input file to data directory: $(basename "$input_file")"
    return 0
}

main() {
    REBUILD=0
    KEEP=0
    COPY_RESULT=0
    VERBOSE=0
    HOST="$DEFAULT_HOST"
    PORT="$DEFAULT_PORT"
    INPUT_FILE=""
    OUTPUT_FILE=""
    CONFIG_FILE="$DEFAULT_CONFIG"
    PASS_THROUGH=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -r|--rebuild)
                REBUILD=1
                shift
                ;;
            -k|--keep)
                KEEP=1
                shift
                ;;
            -c|--copy-result)
                COPY_RESULT=1
                shift
                ;;
            -b|--backend)
                if [ -z "$2" ] || echo "$2" | grep -q '^-'; then
                    echo "Error: --backend requires an argument (podman or docker)" >&2
                    return 1
                fi
                if [ "$2" = "podman" ] || [ "$2" = "docker" ]; then
                    CONTAINER_CMD="$2"
                    echo "Using container backend: $CONTAINER_CMD"
                else
                    echo "Error: Backend must be either 'podman' or 'docker'" >&2
                    return 1
                fi
                shift 2
                ;;
            --host)
                if [ -z "$2" ] || echo "$2" | grep -q '^-'; then
                    echo "Error: --host requires a hostname" >&2
                    return 1
                fi
                HOST="$2"
                shift 2
                ;;
            --port)
                if [ -z "$2" ] || echo "$2" | grep -q '^-'; then
                    echo "Error: --port requires a port number" >&2
                    return 1
                fi
                PORT="$2"
                shift 2
                ;;
            --input)
                if [ -z "$2" ] || echo "$2" | grep -q '^-'; then
                    echo "Error: --input requires a filename" >&2
                    return 1
                fi
                INPUT_FILE="$2"
                shift 2
                ;;
            --output)
                if [ -z "$2" ] || echo "$2" | grep -q '^-'; then
                    echo "Error: --output requires a filename" >&2
                    return 1
                fi
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --config)
                if [ -z "$2" ] || echo "$2" | grep -q '^-'; then
                    echo "Error: --config requires a filename" >&2
                    return 1
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --)
                shift
                PASS_THROUGH=$(printf '%s ' "$@")
                break
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                ;;
        esac
    done
    
    if [ -z "$INPUT_FILE" ]; then
        echo "Error: Input file is required (--input)" >&2
        return 1
    fi
    
    if [ -z "$OUTPUT_FILE" ]; then
        base_name=$(basename "$INPUT_FILE" .h5)
        OUTPUT_FILE="${base_name}_out.h5"
        echo "No output file specified, using: $OUTPUT_FILE"
    fi
    
    if [ "$REBUILD" -eq 1 ] || ! image_exists; then
        build_image || return 1
    fi
    
    prepare_data_dir
    
    copy_input_file "$INPUT_FILE" || return 1
    
    input_filename=$(basename "$INPUT_FILE")
    
    RUN_OPTS="--network=host"
    if [ "$KEEP" -ne 1 ]; then
        RUN_OPTS="$RUN_OPTS --rm"
    fi
    
    echo "Running Gadgetron ISMRMRD client..."
    
    CLIENT_ARGS="--address $HOST --port $PORT --filename $input_filename"
    CLIENT_ARGS="$CLIENT_ARGS --outfile $OUTPUT_FILE --config $CONFIG_FILE"
    
    if [ "$VERBOSE" -eq 1 ]; then
        CLIENT_ARGS="$CLIENT_ARGS -v"
    fi
    
    if [ -n "$PASS_THROUGH" ]; then
        CLIENT_ARGS="$CLIENT_ARGS $PASS_THROUGH"
    fi
    
    CMD="$CONTAINER_CMD run $RUN_OPTS --name $CONTAINER_NAME"
    CMD="$CMD -v $DATA_DIR:/data:Z"
    CMD="$CMD -w /data"
    CMD="$CMD -t $IMAGE_NAME"
    CMD="$CMD $CLIENT_ARGS"
    
    echo "Running command: $CMD"
    eval "$CMD"
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "Command completed successfully"
        echo "Output file: $DATA_DIR/$OUTPUT_FILE"
        
        if [ $COPY_RESULT -eq 1 ] && [ -f "$DATA_DIR/$OUTPUT_FILE" ]; then
            cp "$DATA_DIR/$OUTPUT_FILE" "$(pwd)/"
            echo "Copied result to working directory: $(pwd)/$OUTPUT_FILE"
        fi
    else
        echo "Command failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

main "$@"
exit $?
