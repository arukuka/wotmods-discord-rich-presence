import sys
from py_compile import compile

def main():
    compile(sys.argv[1], sys.argv[2])

if __name__ == '__main__':
    main()
