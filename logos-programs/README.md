# Illustration programs for logOS

These are the small programs that the book runs on logOS to show something: a lost update, a
zombie, a deadlock, a page fault. They are the book's own illustrations, not part of logOS, so
they are not in the [logOS repository](https://github.com/pavelgladyshev/logos); each one is a
single file that uses only logOS's `user/libc.h`.

| Folder | Chapter | logOS version | Programs |
| --- | --- | --- | --- |
| `ch14/` | 14 | Blackrock (branch `2.x-blackrock`) | `fork1`, `fork2`, `zombie`, `rr`, `busy`, `orphan`, `nest`; the shell script `demo.sh` |
| `ch15/` | 15 | Blackrock | `eofwait` |
| `ch17/` | 17 | Blackrock | `race`, `race_flag`, `race_pipe`, `race_intr`; `racediag2`, the variant of `race` that measures a quantum |
| `ch18/` | 18 | Blackrock | `count`, `abc`, `prodcons`, `deadlock` |
| `ch20/` | 20 | Glendalough (branch `3.x-glendalough`) | `where`, `pf`, `shmpt`, `straddle` |

The output printed in the book came from logOS Blackrock v2.1.2 and Glendalough v3.0.2 in Logisim
Evolution UCD 5.0.7. The simulated computer is deterministic, so the same build gives the same
numbers; another version of logOS or of the compiler may give others.

## Adding a program to a logOS tree

1. Copy the `.c` file into the tree's `user/` folder.
2. Add its name, without `.c`, to the list `USER_PROGS` in the tree's `Makefile`.
3. Type `make all`. The program is built and put on the disk image as `/bin/<name>`, so its
   name is a command in the logOS shell.

For example, for `count` of Chapter 18, in a Blackrock tree:

```bash
cp ../bare-metal-os-supplement/logos-programs/ch18/count.c user/
# in the Makefile, add count to the end of the list:   USER_PROGS = hello spawn_demo ... count
make all
make run
```

`demo.sh` of Chapter 14 is a script for the logOS shell, not a C program. Copy it into the top
folder of the tree, and in the `Makefile`, after the line that adds `/etc/test.sh` to the disk
image, add the line (it starts with a tab)

```make
	$(FSTOOL_BIN) add block_storage.bin /etc/demo.sh demo.sh
```

Then `make all`, and in logOS type `sh /etc/demo.sh`.

Two of the programs need a word. `busy` waits for you to type a line. `orphan` leaves a child
running when it ends, and when that child exits Blackrock restarts the shell: that is the bug
the chapter shows, so run it last.

These programs are licensed under CC BY 4.0, like the other examples; see `LICENSE`.
