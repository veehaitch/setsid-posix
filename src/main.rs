use std::os::unix::process::CommandExt;
use std::prelude::v1::Vec;
use std::process;
use std::result::Result::{Err, Ok};
use std::string::String;

use clap::Parser;
use nix::unistd::{getpgrp, getpid, setsid, ForkResult};
use nix::{
    libc::{c_int, wait, EXIT_FAILURE, EXIT_SUCCESS, WEXITSTATUS, WIFEXITED},
    unistd::Pid,
};

fn is_process_group_leader() -> bool {
    getpid() == getpgrp()
}

fn handle_parent(child: Pid, wait_child: bool) {
    if wait_child {
        unsafe {
            let mut wstatus: i32 = 0;
            if wait(&mut wstatus as *mut c_int) != child.as_raw() {
                eprintln!("Failed to wait for child {}", child);
            }

            if WIFEXITED(wstatus) {
                process::exit(WEXITSTATUS(wstatus));
            } else {
                eprintln!("Child {} did not exit normally", child);
                process::exit(EXIT_FAILURE);
            }
        }
    } else {
        process::exit(EXIT_SUCCESS);
    }
}

fn fork(wait_child: bool) {
    match unsafe { nix::unistd::fork() } {
        Ok(ForkResult::Parent { child, .. }) => {
            handle_parent(child, wait_child);
        }
        Ok(ForkResult::Child) => {}
        Err(_) => {
            eprintln!("fork(2) failed");
            process::exit(EXIT_FAILURE);
        }
    }
}

fn create_new_session() {
    if setsid().is_err() {
        eprintln!("setsid(2) failed");
        process::exit(EXIT_FAILURE);
    }
}

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Opts {
    #[arg(
        short,
        long,
        help = "Set the controlling terminal to the current one. Currently not implemented."
    )]
    ctty: bool,
    #[arg(short, long, help = "Always create a new process")]
    fork: bool,
    #[arg(
        short,
        long,
        help = "Wait for the execution of the program to end, and return the exit value of this program as the return value of setsid"
    )]
    wait: bool,
    #[arg(help = "The program to run in a new session")]
    program: String,
    #[arg(help = "The arguments to pass to `program`, if any")]
    arguments: Vec<String>,
}

fn main() {
    let opts = Opts::parse();

    if opts.ctty {
        eprintln!("The --ctty flag is currently not implemented");
        process::exit(EXIT_FAILURE);
    }

    if opts.fork || is_process_group_leader() {
        fork(opts.wait);
    } else if opts.wait {
        eprintln!("Cannot wait without forking. Consider the `--fork` switch.");
        // Not exiting to achieve compatibility with the original `setsid(1)`
    }

    create_new_session();

    process::Command::new(opts.program)
        .args(opts.arguments)
        .exec();
}
