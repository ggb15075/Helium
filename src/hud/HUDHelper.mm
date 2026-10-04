#import <spawn.h>
#import <notify.h>
#import <mach-o/dyld.h>

#import "HUDHelper.h"

#ifdef HELIUM_ROOTHIDE
#include <errno.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <roothide.h>
#include <string>
#endif

extern "C" char **environ;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern "C" int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern "C" int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern "C" int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

#ifdef HELIUM_ROOTHIDE
static int RunAsRoot(const char *executable, const char *const args[])
{
    posix_spawnattr_t attr;
    int result = posix_spawnattr_init(&attr);
    if (result != 0)
        return -result;

    result = posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    if (result == 0)
        result = posix_spawnattr_set_persona_uid_np(&attr, 0);
    if (result == 0)
        result = posix_spawnattr_set_persona_gid_np(&attr, 0);

    pid_t child = -1;
    if (result == 0)
        result = posix_spawn(&child, executable, NULL, &attr, (char *const *)args, environ);
    posix_spawnattr_destroy(&attr);
    if (result != 0)
        return -result;

    int status = 0;
    while (waitpid(child, &status, 0) == -1)
    {
        if (errno != EINTR)
            return -errno;
    }
    return WIFEXITED(status) ? WEXITSTATUS(status) : -EIO;
}

static const char *RootHideLaunchctlPath(const char **virtualPath)
{
    const char *path = jbroot("/bin/launchctl");
    if (path && access(path, X_OK) == 0)
    {
        *virtualPath = "/bin/launchctl";
        return path;
    }
    path = jbroot("/usr/bin/launchctl");
    if (path && access(path, X_OK) == 0)
    {
        *virtualPath = "/usr/bin/launchctl";
        return path;
    }
    return NULL;
}

static int RunHUDLaunchctl(const char *command, const char *arg1,
                           const char *arg2 = NULL, bool logFailure = true)
{
    const char *virtualPath = NULL;
    const char *launchctl = RootHideLaunchctlPath(&virtualPath);
    if (!launchctl)
    {
        os_log_error(OS_LOG_DEFAULT, "RootHide launchctl executable not found");
        return -ENOENT;
    }

    const char *args[] = { virtualPath, command, arg1, arg2, NULL };
    int result = RunAsRoot(launchctl, args);
    if (result != 0 && logFailure)
        os_log_error(OS_LOG_DEFAULT, "launchctl %{public}s failed: %{public}d", command, result);
    return result;
}

static const char *RootHideHUDDomain(void)
{
    static const char *domain = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        domain = "system";
        if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 16 &&
            RunHUDLaunchctl("print", "user/foreground", NULL, false) == 0)
            domain = "user/foreground";
    });
    return domain;
}

static BOOL SetRootHideHUDDisabled(BOOL disabled)
{
    const char *path = jbroot("/var/lib/helium/hud.disabled");
    if (!path)
        return NO;

    if (disabled)
    {
        int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0)
        {
            os_log_error(OS_LOG_DEFAULT, "Cannot disable HUD: marker write failed (%{public}d)", errno);
            return NO;
        }
        if (close(fd) != 0)
        {
            os_log_error(OS_LOG_DEFAULT, "Cannot disable HUD: marker close failed (%{public}d)", errno);
            return NO;
        }
        return YES;
    }

    if (unlink(path) == 0 || errno == ENOENT)
        return YES;
    os_log_error(OS_LOG_DEFAULT, "Cannot enable HUD: marker removal failed (%{public}d)", errno);
    return NO;
}

static char *CurrentExecutablePath(void)
{
    uint32_t size = 0;
    _NSGetExecutablePath(NULL, &size);
    char *path = (char *)calloc(1, size);
    if (!path || _NSGetExecutablePath(path, &size) != 0)
    {
        free(path);
        return NULL;
    }
    return path;
}
#endif

BOOL IsHUDEnabled(void)
{
#ifdef HELIUM_ROOTHIDE
    char *executable = CurrentExecutablePath();
    if (!executable)
        return NO;
    const char *args[] = { executable, "-check", NULL };
    int result = RunAsRoot(executable, args);
    free(executable);
    return result == EXIT_FAILURE;
#else
    static char *executablePath = NULL;
    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    executablePath = (char *)calloc(1, executablePathSize);
    _NSGetExecutablePath(executablePath, &executablePathSize);

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);

    pid_t task_pid;
    const char *args[] = { executablePath, "-check", NULL };
    posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);

#if DEBUG
    os_log_debug(OS_LOG_DEFAULT, "spawned %{public}s -check pid = %{public}d", executablePath, task_pid);
#endif
    
    int status;
    do {
        if (waitpid(task_pid, &status, 0) != -1)
        {
#if DEBUG
            os_log_debug(OS_LOG_DEFAULT, "child status %d", WEXITSTATUS(status));
#endif
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    return WEXITSTATUS(status) != 0;
#endif
}

void SetHUDEnabled(BOOL isEnabled)
{
#ifdef HELIUM_ROOTHIDE
    const char *domain = RootHideHUDDomain();
    std::string service = std::string(domain) + "/com.leemin.helium";

    if (isEnabled)
    {
        if (!SetRootHideHUDDisabled(NO))
            return;
        // A stopped job remains registered after a clean HUD exit. In that
        // state bootstrap may report success without starting it again.
        bool registered = RunHUDLaunchctl("print", service.c_str(), NULL, false) == 0;
        int result = registered
            ? RunHUDLaunchctl("kickstart", "-k", service.c_str())
            : RunHUDLaunchctl("bootstrap", domain,
                              "/Library/LaunchDaemons/com.leemin.helium.plist");
        if (result != 0 && !registered)
            result = RunHUDLaunchctl("kickstart", "-k", service.c_str());
        if (result != 0)
            SetRootHideHUDDisabled(YES);
    }
    else
    {
        if (!SetRootHideHUDDisabled(YES))
            return;
        // bootout stops the one launchd-managed instance. A missing job is
        // already off, so it does not need an -exit helper process.
        if (RunHUDLaunchctl("bootout", service.c_str()) != 0)
            notify_post(NOTIFY_DISMISSAL_HUD);
    }
#else
#ifdef NOTIFY_DISMISSAL_HUD
    notify_post(NOTIFY_DISMISSAL_HUD);
#endif

    static char *executablePath = NULL;
    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    executablePath = (char *)calloc(1, executablePathSize);
    _NSGetExecutablePath(executablePath, &executablePathSize);

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);

    if (isEnabled)
    {
        posix_spawnattr_setpgroup(&attr, 0);
        posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);

        pid_t task_pid;
        const char *args[] = { executablePath, "-hud", NULL };
        posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
        posix_spawnattr_destroy(&attr);

#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "spawned %{public}s -hud pid = %{public}d", executablePath, task_pid);
#endif
    }
    else
    {
        [NSThread sleepForTimeInterval:0.25];

        pid_t task_pid;
        const char *args[] = { executablePath, "-exit", NULL };
        posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
        posix_spawnattr_destroy(&attr);

#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "spawned %{public}s -exit pid = %{public}d", executablePath, task_pid);
#endif
        
        int status;
        do {
            if (waitpid(task_pid, &status, 0) != -1)
            {
#if DEBUG
                os_log_debug(OS_LOG_DEFAULT, "child status %d", WEXITSTATUS(status));
#endif
            }
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    }
#endif
}

void waitForNotification(void (^onFinish)(), BOOL isEnabled) {
#ifdef HELIUM_ROOTHIDE
    // launchctl bootstrap can start the HUD before a notification observer is
    // registered. Poll the actual process instead of missing that one event.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (int attempt = 0; attempt < 20; ++attempt)
        {
            if (IsHUDEnabled() == isEnabled)
                break;
            usleep(250000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            onFinish();
        });
    });
#else
    if (isEnabled)
   {
       dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

       int token;
       notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &token, dispatch_get_main_queue(), ^(int token) {
           notify_cancel(token);
           dispatch_semaphore_signal(semaphore);
       });

       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
           int timedOut = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
           dispatch_async(dispatch_get_main_queue(), ^{
               if (timedOut)
                   os_log_error(OS_LOG_DEFAULT, "Timed out waiting for HUD to launch");
               
               onFinish();
           });
       });
   }
   else
   {
       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           onFinish();
       });
   }
#endif
}
