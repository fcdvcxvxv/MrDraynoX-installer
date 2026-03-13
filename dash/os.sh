
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Failed to detect OS."
        exit 1
    fi

    case "$OS" in
        ubuntu)
            echo "✅ Ubuntu detected. Running ubuntu script..."
            bash ubuntu
            ;;
        debian)
            echo "✅ Debian detected. Running debian script..."
            bash debian
        *)
            echo "❌ Script works only on Ubuntu/Debian"
            exit 1
            ;;
    esac
