package main

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"text/template"

	"github.com/sirupsen/logrus"
	"github.com/spf13/pflag"
	"github.com/spf13/viper"
)

type Shadowsocks struct {
	User     string
	Tag      string
	Server   string
	Port     string
	Cipher   string
	Password string
	UDP      bool
	Sub      bool
}

type Vmess struct {
	User    string
	Tag     string
	Server  string
	Port    string
	Cipher  string
	UUID    string
	AlterID string
	Sub     bool
	// Network string
}

type Socks5 struct {
	User     string
	Tag      string
	Server   string
	Port     string
	UDP      bool
	Auth     string
	Username string
	Password string
	Sub      bool
}

type Http struct {
	User     string
	Tag      string
	Server   string
	Port     string
	Username string
	Password string
	Sub      bool
}

type Outbound struct {
	// socks or http fields
	Protocol string
	Server   string
	Port     string
	Auth     string
	Username string
	Password string

	// vless fields
	UUID       string
	Flow       string
	Encryption string
	Level      string
	Network    string
	Security   string

	// file protocol
	// protocol为file时，File字段表示文件名，此时先读取该文件，然后把文件内容替换到File字段里，用来填充模板
	File string
}

type Config struct {
	Loglevel     string
	LogAccess    string `mapstructure:"log_access"`
	LogError     string `mapstructure:"log_error"`
	VmessPort    int    `mapstructure:"vmess_port"`    // vmess只需要一个端口，多用户使用的是clients数组
	VmessNetwork string `mapstructure:"vmess_network"` // vmess的network字段，可选值: "raw" | "xhttp" | "kcp" | "grpc" | "ws" | "httpupgrade"
	ApiPort      int    `mapstructure:"api_port"`      // api端口
}

type Inbounds struct {
	Vmess       []Vmess
	Shadowsocks []Shadowsocks
	Http        []Http
	Socks5      []Socks5
	Outbound    Outbound

	Config
}

func main() {
	var err error
	configFile := pflag.StringP("config", "c", "config.yaml", "config file")
	templateFile := pflag.StringP("template", "t", "frontendTemplate", "template file")
	outputFile := pflag.StringP("output", "o", "", "output config file, if not set, print to stdout")
	level := pflag.StringP("level", "l", "info", "log level")

	pflag.Parse()

	switch *level {
	case "debug":
		logrus.SetLevel(logrus.DebugLevel)
	case "info":
		logrus.SetLevel(logrus.InfoLevel)
	case "warn":
		logrus.SetLevel(logrus.WarnLevel)
	case "error":
		logrus.SetLevel(logrus.ErrorLevel)
	default:
		logrus.SetLevel(logrus.InfoLevel)
	}

	// 设置配置文件路径
	viper.SetConfigFile(*configFile)
	// 1. 读取配置文件
	err = viper.ReadInConfig()
	if err != nil {
		logrus.Fatalf("Read config file error: %v", err)
	}

	var inbounds Inbounds
	// 2. 解析配置文件到结构体中
	// 现在viper中已经读取了配置文件
	// 使用UnmarshalKey将配置文件中的inbounds部分解析到inbounds结构体中
	err = viper.UnmarshalKey("inbounds", &inbounds)
	if err != nil {
		logrus.Fatalf("Decode inbounds error: %v", err)
	}

	// 3. 把tag中的端口号解析出来放到port字段
	// 配置文件中没有单独的port信息，port信息在tag中
	// (net traffic会使用tag中的port来监控流量），config文件中没有单独的port信息
	// 因此需要把tag中的port信息提取出来，放到结构体的Port字段内
	for i := range inbounds.Http {
		fields := strings.Split(inbounds.Http[i].Tag, ":")
		if len(fields) < 3 {
			logrus.Fatalf("Http tag format incorrect")
		}
		inbounds.Http[i].Port = fields[1]
	}
	for i := range inbounds.Vmess {
		fields := strings.Split(inbounds.Vmess[i].Tag, ":")
		if len(fields) < 3 {
			logrus.Fatalf("Vmess tag format incorrect")
		}
		inbounds.Vmess[i].Port = fields[1]
	}
	for i := range inbounds.Shadowsocks {
		fields := strings.Split(inbounds.Shadowsocks[i].Tag, ":")
		if len(fields) < 3 {
			logrus.Fatalf("Shadowsocks tag format incorrect")
		}
		inbounds.Shadowsocks[i].Port = fields[1]
	}
	for i := range inbounds.Socks5 {
		fields := strings.Split(inbounds.Socks5[i].Tag, ":")
		if len(fields) < 3 {
			logrus.Fatalf("Socks5 tag format incorrect")
		}
		inbounds.Socks5[i].Port = fields[1]
	}
	logrus.Debugf("inbounds: %+v", inbounds)

	if inbounds.Outbound.Protocol == "file" {
		bs, err := os.ReadFile(inbounds.Outbound.File)
		if err != nil {
			logrus.Fatalf("read file: %v error", inbounds.Outbound.File)
		}
		inbounds.Outbound.File = string(bs)
	}

	var b bytes.Buffer
	// 4. 解析模板文件
	tmpl, err := template.ParseFiles(*templateFile)
	if err != nil {
		logrus.Fatalf("Parse template file error: %v", err)
	}
	// 5. 渲染模板文件
	err = tmpl.ExecuteTemplate(&b, "all", &inbounds)
	if err != nil {
		logrus.Fatalf("Execute template file error: %v", err)
	}

	// 6. 输出结果
	if len(*outputFile) > 0 {
		// 如果指定了输出文件，则将结果写入文件
		logrus.Infof("Write to file: %v", *outputFile)
		err = os.WriteFile(*outputFile, b.Bytes(), 0644)
		if err != nil {
			logrus.Fatalf("Write output file error: %v", err)
		}
	} else {
		// 如果未指定输出文件，则将结果打印到stdout
		fmt.Print(b.String())
	}
}
