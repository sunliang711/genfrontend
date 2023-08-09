package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
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
	Network string
	Sub     bool
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
	Loglevel string
	Logfile  string
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
	outputFile := pflag.StringP("output", "o", "", "output config file")
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

	viper.SetConfigFile(*configFile)
	err = viper.ReadInConfig()
	if err != nil {
		logrus.Fatalf("Read config file error: %v", err)
	}

	tmpl, err := template.ParseFiles(*templateFile)
	if err != nil {
		logrus.Fatalf("Parse template file error: %v", err)
	}
	var inbounds Inbounds
	err = viper.UnmarshalKey("inbounds", &inbounds)
	if err != nil {
		logrus.Fatalf("Decode inbounds error: %v", err)
	}
	// port信息放在tag中（net traffic会使用tag中的port来监控流量），config文件中没有单独的port信息
	// 因此需要把tag中的port信息提取出来，放到结构体的Port字段内

	// 把tag中的端口号解析出来放到port字段
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
		bs, err := ioutil.ReadFile(inbounds.Outbound.File)
		if err != nil {
			logrus.Fatalf("read file: %v error", inbounds.Outbound.File)
		}
		inbounds.Outbound.File = string(bs)
	}

	var b bytes.Buffer
	tmpl.ExecuteTemplate(&b, "all", &inbounds)
	if len(*outputFile) > 0 {
		logrus.Infof("Write to file: %v", *outputFile)
		err = ioutil.WriteFile(*outputFile, b.Bytes(), 0644)
		if err != nil {
			logrus.Fatalf("Write output file error: %v", err)
		}
	} else {
		fmt.Print(b.String())
	}
}
