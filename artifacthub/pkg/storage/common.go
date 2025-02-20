package storage

import (
	"fmt"
	"mime"
	"os"
	"path/filepath"
	"strings"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"go.uber.org/zap"
)

func AppendContentType(mimes map[string]bool, extraMimes map[string]string, URL, path string) string {
	fileType := filepath.Ext(path)
	if m, ok := extraMimes[fileType]; ok { // force extra mime
		return fmt.Sprintf("%s&response-content-disposition=inline&response-content-type=%s", URL, m)
	}

	m := mime.TypeByExtension(fileType) // the real mime of that file type
	if _, ok := mimes[m]; ok {          // if we need it to be openable in browser
		return fmt.Sprintf("%s&response-content-disposition=inline&response-content-type=%s", URL, m)
	}

	return URL // will download as before
}

func LoadMimes() map[string]bool {
	mimes := map[string]bool{}
	oib := os.Getenv("OPEN_IN_BROWSER")
	if len(oib) == 0 {
		log.Warn("OPEN_IN_BROWSER is empty")
	} else {
		parts := strings.Split(oib, ",")
		for _, p := range parts {
			mimes[p] = true
		}
	}

	return mimes
}

func LoadExtraMimes() map[string]string {
	extraMimes := map[string]string{}

	oom := os.Getenv("OIB_OTHER_MIMES")
	if len(oom) == 0 {
		log.Warn("OIB_OTHER_MIMES is empty")
	} else {
		parts := strings.Split(oom, ",")
		for _, p := range parts {
			px := strings.SplitN(p, ":", 2)
			if len(px) != 2 {
				log.Error("OIB_OTHER_MIMES should look like .ext:some_mime,.ext2:some_mime2",
					zap.String("found part without :", p))
				continue
			}

			if !strings.HasPrefix(px[0], ".") {
				log.Warn("file type in OIB_OTHER_MIMES should start with a '.'",
					zap.String("found ext", px[0]))
			}

			extraMimes[px[0]] = px[1]
		}
	}

	return extraMimes
}
