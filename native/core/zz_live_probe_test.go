package core

import (
	"context"
	"os"
	"testing"
	"time"
)

// 临时实网探针：LIVE_PROBE=1 时跑，验证站源目录/详情/取流链路。用完即删，不进 CI。
func TestZZLiveProbe(t *testing.T) {
	if os.Getenv("LIVE_PROBE") != "1" {
		t.Skip("live probe disabled")
	}
	engine, err := newNativeEngine(t.TempDir(), "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(engine.downloads.close)
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	for _, source := range []string{"hongguo", "huangdou"} {
		catalog, err := engine.nativeCatalog(ctx, nativeInput{Source: source, Page: 1})
		if err != nil {
			t.Logf("[%s] 目录失败: %v", source, err)
			continue
		}
		t.Logf("[%s] 目录 %d 条", source, len(catalog.Items))
		probed := 0
		ok := 0
		for _, drama := range catalog.Items {
			if probed >= 3 {
				break
			}
			detail, err := engine.nativeDetail(ctx, drama)
			if err != nil {
				t.Logf("[%s] %s 详情失败: %v", source, drama.Title, err)
				continue
			}
			rows, _ := detail.(map[string]any)
			chapters, _ := rows["chapters"].([]Chapter)
			if len(chapters) == 0 {
				t.Logf("[%s] %s 无分集", source, drama.Title)
				continue
			}
			probed++
			task := Task{DramaID: drama.ID, DramaTitle: drama.Title, Chapter: chapters[0], Index: 1}
			media, err := engine.downloader.resolveProviderMedia(ctx, task)
			if err != nil {
				t.Logf("[%s] %s 第1集取流失败: %v", source, drama.Title, err)
				continue
			}
			ok++
			t.Logf("[%s] %s 第1集取流成功 url=%.60s", source, drama.Title, media.URL)
		}
		t.Logf("[%s] 取流 %d/%d 成功", source, ok, probed)
	}
}
