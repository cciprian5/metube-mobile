#ifndef RUNNER_RUN_NOTE_H_
#define RUNNER_RUN_NOTE_H_

// Leaves a note for the next start when this process crashes, in native code
// no Dart handler ever sees. Call once, before the engine starts.
void InstallRunNote();

// Windows is logging off or shutting down: the app will not get to close
// itself, and that is not a crash.
void NoteWindowsEnding();

#endif  // RUNNER_RUN_NOTE_H_
