namespace SimpleSmartMail.Models.Enums;

public enum EmailStatus
{
    Queued = 0,
    Processing = 1,
    Sent = 2,
    Delivered = 3,
    Opened = 4,
    Clicked = 5,
    Bounced = 6,
    Failed = 7,
    SpamComplaint = 8,
    Unsubscribed = 9
}
