// Message bus for the collector. It'll read from a message queue and
// send the data to another queue.
// More specifically, from a public queue to a private queue.

use amiquip::{Connection, ConsumerMessage, ConsumerOptions, QueueDeclareOptions, Publish, Exchange};

use color_eyre::eyre::{eyre, Result};


pub struct Config {
    pub amqp_url: String,
    pub public_queue: Option<String>,
    pub private_queue: Option<String>,
    pub channel_id: Option<u16>,
}

// Main struct for the bus
// Listens to the message queue and sends the data to another queue
pub struct Bus {
    config: Config,
}

impl Bus {
    pub fn new(config: Config) -> Self {
        Self { config }
    }

    pub fn listen(&self) -> Result<()> {
        let mut connection = Connection::insecure_open(&self.config.amqp_url)?;

        let channel = connection.open_channel(self.config.channel_id)?;

        let queue = channel.queue_declare(
            self.config.public_queue.as_ref().unwrap_or(&"q1".to_string()),
            QueueDeclareOptions::default(),
        )?;

        let consumer = queue.consume(ConsumerOptions::default())?;

        for(i, message) in consumer.receiver().iter().enumerate() {
            match message {
                ConsumerMessage::Delivery(delivery) => {
                    let body = String::from_utf8_lossy(&delivery.body);
                    tracing::info!("({:>3}) Received [{}]", i, body);
                    if body == "quit" {
                        tracing::info!("Quitting");
                        break;
                    }
                    consumer.ack(delivery)?;
                }
                other => {
                    tracing::info!("Consumer ended: {:?}", other);
                    break;
                }
            }
        }

        connection.close().map_err(|e| eyre!(e))?;

        Ok(())
    }

    // todo: implement data struct.
    pub fn send(&self, data: &str) -> Result<()> {
        let mut connection = Connection::insecure_open(&self.config.amqp_url)?;

        let channel = connection.open_channel(self.config.channel_id)?;

        let exchange = Exchange::direct(&channel);
        exchange.publish(Publish::new(data.as_bytes(), "q1"))?;

        connection.close().map_err(|e| eyre!(e))?;

        Ok(())
    }
}
