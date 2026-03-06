package slack

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const timezone = "Europe/Oslo"

type Client struct {
	userToken string
	botToken  string
	http      *http.Client
}

func New(userToken, botToken string) *Client {
	return &Client{
		userToken: userToken,
		botToken:  botToken,
		http:      &http.Client{Timeout: 10 * time.Second},
	}
}

func (c *Client) SetStatus(userID, text, emoji string) (map[string]any, error) {
	body, _ := json.Marshal(map[string]any{
		"profile": map[string]any{
			"status_text":       text,
			"status_emoji":      emoji,
			"status_expiration": endOfToday(),
		},
		"user": userID,
	})
	return c.post("https://slack.com/api/users.profile.set", c.userToken, body)
}

func (c *Client) SendDM(userID, text string) (map[string]any, error) {
	body, _ := json.Marshal(map[string]any{
		"channel": userID,
		"text":    text,
		"metadata": map[string]any{
			"event_type":    "status_set",
			"event_payload": map[string]any{},
		},
	})
	return c.post("https://slack.com/api/chat.postMessage", c.botToken, body)
}

func (c *Client) OpenModal(triggerID string, view map[string]any) (map[string]any, error) {
	body, _ := json.Marshal(map[string]any{
		"trigger_id": triggerID,
		"view":       view,
	})
	return c.post("https://slack.com/api/views.open", c.botToken, body)
}

func (c *Client) post(url, token string, body []byte) (map[string]any, error) {
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, fmt.Errorf("slack API response parse error: %w", err)
	}
	return result, nil
}

func endOfToday() int64 {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		loc = time.FixedZone("CET", 3600)
	}
	now := time.Now().In(loc)
	end := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 0, 0, loc)
	return end.Unix()
}
