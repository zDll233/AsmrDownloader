#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Remember which window the user was in *before* we create ours.
  //
  // Doing this from Dart is too late: the native window already exists by the
  // time main() runs, so GetForegroundWindow() would only ever see our own
  // window (or the console). The Dart side reads it back from the command line
  // to look for text the user had selected in that application (e.g. an
  // RJxxxxxx id on a web page) before falling back to the clipboard.
  HWND launch_foreground = ::GetForegroundWindow();

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Pass the captured handle along with the user supplied arguments.
  // HWND values fit in 32 bits on Windows (and Dart has no 64-bit int type on
  // the web), so pass the low 32 bits.
  UINT32 launch_foreground_value =
      static_cast<UINT32>(reinterpret_cast<ULONG_PTR>(launch_foreground));
  command_line_arguments.push_back(
      "--launch_foreground_window=" + std::to_string(launch_foreground_value));

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"AsmrDownloader", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
