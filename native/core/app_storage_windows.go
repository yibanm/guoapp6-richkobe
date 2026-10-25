package core

import (
	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

func nativeFreeSpace(path string) int64 {
	value, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return -1
	}
	var available, total, free uint64
	if windows.GetDiskFreeSpaceEx(value, &available, &total, &free) != nil {
		return -1
	}
	return int64(available)
}

// nativeWindowsVideosFolder 读取用户「视频」库的真实位置（侧边栏可自定义），
// 注册表缺失或被清空时回退 %USERPROFILE%\Videos。
func nativeWindowsVideosFolder() (string, error) {
	key, err := registry.OpenKey(registry.CURRENT_USER,
		`Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`, registry.QUERY_VALUE)
	if err != nil {
		return "", err
	}
	defer key.Close()
	value, _, err := key.GetStringValue("My Video")
	if err != nil || value == "" {
		return "", err
	}
	expanded, err := registry.ExpandString(value)
	if err != nil || expanded == "" {
		return value, nil
	}
	return expanded, nil
}
