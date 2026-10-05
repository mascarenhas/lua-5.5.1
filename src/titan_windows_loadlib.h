/* Included only by the controlled Lua 5.5.1 loadlib.c Windows branch.
** '!' remains relative to the running EXE; requested providers may be anywhere,
** but their dependencies resolve only from that EXE's directory and System32.
** Buffers belong to Lua, including across allocation errors/longjmp. */
#include <windows.h>
#include <limits.h>
#include <wchar.h>

#define TITAN_WINDOWS_PATH_CAP 32768u

static void titan_win_pusherror (lua_State *L, DWORD error) {
  WCHAR wide[256];
  char utf8[1024];
  DWORD count = FormatMessageW(FORMAT_MESSAGE_IGNORE_INSERTS |
      FORMAT_MESSAGE_FROM_SYSTEM, NULL, error, 0, wide, 256, NULL);
  int bytes = count ? WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
      wide, (int)count, utf8, sizeof(utf8), NULL, NULL) : 0;
  if (bytes > 0)
    lua_pushlstring(L, utf8, (size_t)bytes);
  else
    lua_pushfstring(L, "system error %I", (lua_Integer)error);
}

/* Lua paths are length-bearing strings; never silently load a NUL prefix. */
static const char *titan_win_checkstring (lua_State *L, int index) {
  size_t length;
  const char *value = luaL_checklstring(L, index, &length);
  if (length >= INT_MAX || memchr(value, '\0', length) != NULL)
    luaL_error(L, "embedded NUL or oversized Windows path/name");
  return value;
}
#undef luaL_checkstring
#define luaL_checkstring(L,n) titan_win_checkstring(L,n)

#undef setprogdir
static void setprogdir (lua_State *L) {
  int original = lua_gettop(L);
  DWORD capacity = 256;
  WCHAR *wide;
  WCHAR *last;
  char *utf8;
  int bytes;
  for (;;) {
    DWORD length;
    wide = (WCHAR *)lua_newuserdatauv(L, capacity * sizeof(WCHAR), 0);
    length = GetModuleFileNameW(NULL, wide, capacity);
    if (length == 0) {
      DWORD error = GetLastError();
      titan_win_pusherror(L, error);
      lua_error(L);
    }
    if (length < capacity) break;
    lua_pop(L, 1);
    if (capacity == TITAN_WINDOWS_PATH_CAP)
      luaL_error(L, "Windows executable path exceeds supported length");
    capacity *= 2;
    if (capacity > TITAN_WINDOWS_PATH_CAP) capacity = TITAN_WINDOWS_PATH_CAP;
  }
  last = wcsrchr(wide, L'\\');
  if (last == NULL) luaL_error(L, "unable to get executable directory");
  *last = L'\0';
  bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1,
      NULL, 0, NULL, NULL);
  if (bytes == 0) {
    DWORD error = GetLastError();
    titan_win_pusherror(L, error);
    lua_error(L);
  }
  utf8 = (char *)lua_newuserdatauv(L, (size_t)bytes, 0);
  if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1,
      utf8, bytes, NULL, NULL)) {
    DWORD error = GetLastError();
    titan_win_pusherror(L, error);
    lua_error(L);
  }
  luaL_gsub(L, lua_tostring(L, original), LUA_EXEC_DIR, utf8);
  lua_replace(L, original);
  lua_settop(L, original);
}

static void lsys_unloadlib (void *lib) {
  FreeLibrary((HMODULE)lib);
}

static void *lsys_load (lua_State *L, const char *path, int seeglb) {
  int top = lua_gettop(L);
  int count;
  WCHAR *wide;
  WCHAR *absolute;
  DWORD capacity;
  DWORD length;
  DWORD error;
  HMODULE library;
  (void)seeglb;
  /* Lua call sites checked embedded NUL before reaching this C-string API. */
  if (strlen(path) >= INT_MAX) {
    lua_pushliteral(L, "oversized Windows library path");
    return NULL;
  }
  count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
  if (count == 0) goto failed;
  if ((unsigned)count > TITAN_WINDOWS_PATH_CAP) {
    SetLastError(ERROR_FILENAME_EXCED_RANGE);
    goto failed;
  }
  wide = (WCHAR *)lua_newuserdatauv(L, (size_t)count * sizeof(WCHAR), 0);
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, count))
    goto failed;
  capacity = GetFullPathNameW(wide, 0, NULL, NULL);
  if (capacity == 0) goto failed;
  for (;;) {
    if (capacity > TITAN_WINDOWS_PATH_CAP) {
      SetLastError(ERROR_FILENAME_EXCED_RANGE);
      goto failed;
    }
    absolute = (WCHAR *)lua_newuserdatauv(L, capacity * sizeof(WCHAR), 0);
    length = GetFullPathNameW(wide, capacity, absolute, NULL);
    if (length == 0) goto failed;
    if (length < capacity) break;
    lua_pop(L, 1);
    if (capacity == TITAN_WINDOWS_PATH_CAP) {
      SetLastError(ERROR_FILENAME_EXCED_RANGE);
      goto failed;
    }
    /* Grow monotonically even if another thread changes the process CWD. */
    capacity *= 2;
    if (capacity > TITAN_WINDOWS_PATH_CAP) capacity = TITAN_WINDOWS_PATH_CAP;
    if (length > capacity) capacity = length;
  }
  library = LoadLibraryExW(absolute, NULL,
      LOAD_LIBRARY_SEARCH_APPLICATION_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (library == NULL) goto failed;
  lua_settop(L, top);
  return library;
failed:
  error = GetLastError();
  lua_settop(L, top);
  titan_win_pusherror(L, error);
  return NULL;
}

static lua_CFunction lsys_sym (lua_State *L, void *lib, const char *sym) {
  lua_CFunction function = cast_Lfunc(GetProcAddress((HMODULE)lib, sym));
  if (function == NULL) {
    DWORD error = GetLastError();
    titan_win_pusherror(L, error);
  }
  return function;
}
