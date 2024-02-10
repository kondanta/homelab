
use std::str::FromStr;
use std::fmt;

use lib::bus;
use color_eyre::eyre::eyre;

#[derive(Debug, Clone)]
pub(super) enum QueueType {
    Discord,
    Drink,
    Game,
    Killswitch,
    Waker,
    Work,
}

struct QueueTypeIterator {
    index: usize,
}

impl Iterator for QueueTypeIterator {
    type Item = QueueType;

    fn next(&mut self) -> Option<Self::Item> {
        let variants = [
            QueueType::Discord,
            QueueType::Drink,
            QueueType::Game,
            QueueType::Killswitch,
            QueueType::Waker,
            QueueType::Work,
        ];

        if self.index < variants.len() {
            let variant = variants[self.index].clone();
            self.index += 1;
            Some(variant)
        } else {
            None
        }
    }
}

impl QueueType {
    fn iter() -> QueueTypeIterator {
        QueueTypeIterator { index: 0 }
    }
}

impl FromStr for QueueType {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err>{
        match s {
            "discord" => Ok(QueueType::Discord),
            "drink" => Ok(QueueType::Drink),
            "game" => Ok(QueueType::Game),
            "killswitch" => Ok(QueueType::Killswitch),
            "waker" => Ok(QueueType::Waker),
            "work" => Ok(QueueType::Work),
            _ => Err(())
        }
    }
}

impl fmt::Display for QueueType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            QueueType::Discord => write!(f, "discord"),
            QueueType::Drink => write!(f, "drink"),
            QueueType::Game => write!(f, "game"),
            QueueType::Killswitch => write!(f, "killswitch"),
            QueueType::Waker => write!(f, "waker"),
            QueueType::Work => write!(f, "work"),
        }
    }
}

impl QueueType{
    fn channel_id(&self) -> u16 {
        match self {
            QueueType::Discord => 10,
            QueueType::Drink => 11,
            QueueType::Game => 12,
            QueueType::Killswitch => 13,
            QueueType::Waker => 14,
            QueueType::Work => 15,
        }
    }
}

#[derive(Debug)]
pub struct Queue {
    bus: bus::Bus,
}

impl Queue {
    pub fn init() {
        tracing::info!("Initializing queues");
    // for each queuetype, create a queue
        for queue in QueueType::iter() {

            let bus = bus::Bus::new();
            bus.create_queue(
                queue.to_string(),
                Some(queue.channel_id())
            ).unwrap();
            tracing::info!("Queue {} initialized", queue);
        }
        tracing::info!("Queues initialized");
    }

    pub fn new() -> Self {
        let bus = bus::Bus::new();
        Self { bus }
    }

    // Distribute the data to the appropriate topic in the queue
    #[tracing::instrument]
    pub(super) fn dispatch(
        &self,
        request: crate::http::Request
    ) -> color_eyre::Result<()> {
        let span = tracing::span!(tracing::Level::INFO, "dispatch");
        let _enter = span.enter();
        // Find which queue to send the data to
        let queue = self.picker(request.requestee())?;
        let message = crate::http::Message::new(request);

        self.bus.send(message, Some(queue.channel_id())).unwrap();

        Ok(())
    }

    #[tracing::instrument]
    fn picker(&self,  to: &str) -> color_eyre::Result<QueueType> {
        tracing::info!("Picking queue for {}", to);
        let queue = QueueType::from_str(&to).map_err(|_| eyre!("Invalid queue"))?;
        Ok(queue)
    }

}
