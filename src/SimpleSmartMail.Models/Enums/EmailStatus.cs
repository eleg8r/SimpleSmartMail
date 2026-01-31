namespace SimpleSmartMail.Models.Enums;

public enum EmailStatus
{
    Queued = 0,
    Processing = 1,
    Sent = 2,
    Accepted = 3,
    Delivered = 4,
    Opened = 5,
    Clicked = 6,
    Bounced = 7,
    Failed = 8,
    SpamComplaint = 9,
    Unsubscribed = 10
}
