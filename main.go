package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/gofiber/fiber/v2"
)

var (
	WebPort     string
	DefaultPort = "3123"
)

func init() {
	if WebPort == "" {
		WebPort = os.Getenv("WEB_PORT")
	}
	if WebPort == "" {
		log.Println("port is not set - default to: ", DefaultPort)
		WebPort = DefaultPort
	}
}

func main() {
	app := fiber.New()

	app.Get("/", func(c *fiber.Ctx) error {
		return c.SendString("Hello, Docker! <3")
	})

	app.Get("/test", func(c *fiber.Ctx) error {
		message := "Hi Everyone!"
		datetime := time.Now().Format("2006-01-02 15:04:05")
		return c.JSON(fiber.Map{
			"status":  "ok",
			"message": message,
			"date":    datetime,
		})
	})

	err := app.Listen(fmt.Sprintf(":" + WebPort))
	if err != nil {
		log.Fatalf("error on listen: %v", err)
	}
}
