package logger

import (
	"os"
	"strings"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Log *zap.Logger

func Init(level, format string) {
	var lvl zapcore.Level
	switch strings.ToLower(level) {
	case "debug":
		lvl = zapcore.DebugLevel
	case "warn":
		lvl = zapcore.WarnLevel
	case "error":
		lvl = zapcore.ErrorLevel
	default:
		lvl = zapcore.InfoLevel
	}
	encCfg := zap.NewProductionEncoderConfig()
	encCfg.EncodeTime = zapcore.ISO8601TimeEncoder
	encCfg.EncodeLevel = zapcore.LowercaseLevelEncoder
	var enc zapcore.Encoder
	if strings.ToLower(format) == "console" {
		enc = zapcore.NewConsoleEncoder(encCfg)
	} else {
		enc = zapcore.NewJSONEncoder(encCfg)
	}
	Log = zap.New(zapcore.NewCore(enc, zapcore.AddSync(os.Stdout), lvl),
		zap.AddCaller(), zap.AddStacktrace(zapcore.ErrorLevel))
}

func Info(msg string, f ...zap.Field)  { Log.Info(msg, f...) }
func Warn(msg string, f ...zap.Field)  { Log.Warn(msg, f...) }
func Error(msg string, f ...zap.Field) { Log.Error(msg, f...) }
func Debug(msg string, f ...zap.Field) { Log.Debug(msg, f...) }
