pub trait Message {
    fn requestee(&self) -> &str;
    fn requestor(&self) -> &str;
    fn payload(&self) -> &str;
    fn to_json(&self) -> serde_json::Value;
}