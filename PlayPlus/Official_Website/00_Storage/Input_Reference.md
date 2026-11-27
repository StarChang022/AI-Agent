# Can Smart Factory Solutions Solve the Visibility Challenges Created by Legacy Systems

When we look at a legacy plant today, one thing addresses clearly: the machines are generating data. Various devices such as, PLCs, CNCs, SCADA systems, controllers, production equipment, and other machines are continuously recording what is happening on the shop floor. Major challenge is that much of this data remains within the systems that generate it.

We often see machines from different generations working side by side. Some use older controllers or communication protocols, where newer systems may use completely different interfaces. Each system may be doing its job, but the plant does not necessarily get a connected view of what is happening across them.

This matters because plant operations do not happen in isolation. A change in one machine can affect production, quality, maintenance, or another process. When the systems are disconnected, we may have the data, but we cannot always see the complete picture in time.

That is why operational visibility matters in legacy plants, and how smart factory solutions become centre part to solve it. The real challenge is not simply that data exists. It is whether we can bring that information together and turn it into a clear understanding of what is happening on the factory floor.

Let us first understand how legacy system breaks the path from data to action.

## How Legacy Systems Break the Path from Data to Action

So, where does operational visibility actually start to break? When we talk about brownfield plants, major issues are discovered almost in any stage. Sometimes, we receive appropriate machine data, sometimes we do not know what exactly that means.

Also, machines failed to take appropriate necessary actions by themselves, so they still require human intervention. Which leads the operational visibility gap in any stage during the operation. This happens because the legacy systems are not following the proper chain of process as below:

Formal checks for CDC and RDC should make sure that the behavior of asynchronous signals and resets is correct. Special attention is needed for situations that could cause unstable signals, reset order, and how synchronizers are used.

Any exceptions should be checked and recorded before finalizing the [RTL design](https://moschip.com/design-services/).

### Connect: Getting the Data Is the First Challenge

Majorly visibility gap appears at the starting point because of various legacy systems such as PLCs, controllers, and other equipment are designed to operate independently by their own. These systems still use outdated protocols, proprietary interfaces, vendor-specific communication channels, these leads OT and IT integration difficult at that point.

So, the system needs to be updated with gateways, new protocol conversions, adapters, or custom interfaces which can bring data into connected environment.

Once this connectivity established in system, the operational visibility starts at blind spot, because context is just connected based on real-time data but it is still missing in contextualization.

### Contextualize: Data Needs Meaning

Once our data is connected, we also need the behind story of the connected data that what it wants to say to us (hidden context of the operation on floor).

Let us understand by an example, when we see some temperature reading like 85°C which gives us an acknowledgement information from machine data, what are the process running, on which product or batch it produced, and what was the machine state that time. As we know, various machines have various methods to represent the Same information using tags, units, formats, and data structures.

So, we can see the signals which were generated, but without this context, we cannot clearly state the operating condition of the machines.

### Understand: The Bigger Picture Is Still Missing

Now, moving ahead in visibility gaps, when we receive appropriate real-time machine information that needs to be understood properly based on the situation occurred in different systems. Such as, PLCs contain machine conditions, SCADA refers alarming conditions, where MES represents production information, while CMMS, historians, and quality systems contain various piece of the story.

But the major turning point is the legacy systems remain disconnected, as we can various situations occurs separately but not in connected way.

If machine condition or surround environment may face changes, will the production, maintenance, quality, or other operating condition will sustain/understand the change itself?

This means we have data from different parts of the plant, but not a complete operational picture.

![](https://www.design-reuse-embedded.com/IMAGES/NEWS-IMAGES/1_1792051523358.webp)

### Predict: Limited Data Limits Foresight

Once we got the proper picture of the operation, forward way becomes tough to understand. Not just because of human intervention, now the time will play huge role. How? Let’s see.

As we know prediction of the outcome depends on the historical and real-time information which are generated by machines in right context.

So, if the generated foundation flaws, it becomes difficult to trace the patterns that leads operators and plant heads towards right equipment failures, process deviations, quality issues, and downwards of performance.

The visibility gap now moves along with fully understanding of what exactly is happening and how to be responded next.

### Recommend: When Insight Does Not Become Direction

To understand this stage, we took an example that if machine starts to identify the inner issues which are created inside machine, which gives useful information based on real-time situation, but what to do with that information still need to be determined.

Because appropriate response may be dependent of the asset/machine’s criticality, production schedules, maintenance history, operating conditions, spare parts availability and other priorities.

Without this operational context, visibility may inform us about what happened wrong inside the factory floor, but it cannot clarify how to respond this. This not only lead to reduce operational visibility, but this also leads to poor plant efficiency and lower quality of production.

### Act: When Visibility Does Not Lead to Action

This stage leads us to the major factor of the visibility gap because it is about to execute the right action on right gaps. Because systems still operate on human intervention, where operators still need to understand the flagged situation, investigate it, and raise maintenance request, on which the operator can take appropriate action manually.

So, now plants may have connected systems, they collect the data, generate proper information but it just recommends the action to be taken. This creates an open-loop system inside the plant floor to complete this chain process due to human intervention.

Because data without the contextual understanding and simply generates the recommendations without having authority to implement own decisions on the operation, the legacy systems/machines break the operational visibility.

Simply we can say:

*   Data ≠ contextual understanding,
*   Understanding ≠ predict right response,
*   Proper response ≠ Still require human inputs to complete the loop.

The goal is not simply to connect legacy machines, but to rebuild the new path where machines can freely operate and maintain themselves by understanding, anticipating, and responding.

So, how do smart factory solutions [modernize a brownfield environment](https://moschip.com/blog/digital-engineering/modernizing-legacy-systems-with-industrial-iot-solutions/) without replacing everything that already works?

## Legacy Modernization: Building the Path from Data to Action

In last, we discussed about operational visibility gaps. These doesn’t mean to rip and replace the whole legacy systems on the floor every time. In most of the brownfield plants, PLCs, RTUs, CNCs, and other controllers are still operating their functions.

But the challenge lies with this system still operate under isolated environment in plant floor. So, from engineering side, smart factory solutions can be built around the missing layers properly with the existing assets rather replacing them.

So, how these layers can be arranged?

We require reliable access of machine data without affecting control cycles, which can easily operate, maintain, and correlate with plant information before using it for prediction, decision-making, and execute to solutions.

The objective can fulfil by build reliable complete path:

**_CONNECT →_** **_CONTEXTUALIZE →_** **_UNDERSTAND →_** **_PREDICT →_** **_RECOMMEND →_** **_ACT_**

### Connect: Bring Existing Equipment into the Modern Architecture

Now, the new chain begins with the major part in legacy system is connectivity.

Older PLC may use port, RS232 or RS485, to communicate with necessary information which required for PLC operations. Where, CNC machines could use the fieldbus or legacy version Ethernet. And other controllers may utilize various vendor-specific interface.

Also, protocols can be varied based on modernization. Depending on the equipment, we may come across Modbus RTU/TCP, PROFIBUS DP, CANopen, Allen-Bradley DH+, EtherNet/IP, or PROFINET.

The first step is to access this data without disturbing the original control system. Machines should continue their process as it is. We are only just creating a reliable way for information which are already produces.

This is where an industrial edge gateway can be placed between the machine and the modern plant network. The gateway can collect data from different interfaces, filter the information which we need, can add timestamps, and can temporarily store it when the network connection is unavailable. Once the connection is restored, the stored data can be forwarded to the next system.

There can also be cases where the controller simply does not provide the signal we need. In those situations, we can add retrofit sensors or external I/O modules for parameters such as vibration, temperature, current, or other equipment conditions.

Once the data reaches the gateway, it can be sent further into the plant using northbound protocols such as MQTT, Sparkplug B, or OPC UA, depending on the existing plant architecture.

So, the basic flow becomes:

**Legacy Machines → Existing Interface → Edge Gateway → Northbound Protocol → Modern Plant Network**

Our machine still in operation.

But now, we can just see it’s a data.

### Contextualize: Give the Data Meaning

Just seeing the data is not enough. We need to move ahead to understanding.

A register value itself cannot pass much information. This is same for alarm code or an analog signal.

What we need to know here?

*   We need to know first from where the signals came?
*   We also need to understand its representation.
*   Also, what our legacy machine was doing when it was recorded?

As we know various legacy system generates various types of machine data, so first we need to bring these data into common structure.

For this, we need to bring the data normalization, schema mapping, timestamp alignment, unit conversion, and metadata binding.

Why we need this?

Because different machines using different tag names and data formats. Various sample rates, also various IDs.

We need to map all these data into same page such as:

*   Asset ID and location
*   Process and production line
*   Production order
*   Product and batch
*   Machine state
*   Quality events
*   Maintenance events

An ISA-95-based structure can also help to organize the relation between equipment, operations, production, and enterprise-level information.

Now, we can see that, a temperature value is not just 85. We know from which asset it is generated, also the process and machine state involved at that time, and the time of reading captured.

Now the contextual data turns from vision to meaningful data.

**Raw telemetry becomes operational information.**

### Understand: Connect the Different Pieces

Now here, we can see and understand the state of the data.

But we still missing the understanding layer, so whole picture still hidden.

What we have till now?

*   SCADA may have the alarm,
*   MES may have the production order,
*   Historian may have the trend,
*   CMMS may have the maintenance history.
*   ERP may contain material or order information.
*   Quality systems may contain the inspection result.

First, we need to bring all these pieces such as APIs, data pipelines, historians, asset models, time synchronization, and event correlation together.

To understand this, let’s have the example:

Suppose the motor current starts increases. We know that this value alone is not enough to deliver the proper context and understand what is happening?

We can make comparison with machine state, amount of production, maintenance history, material condition, and previous operating behavior. This gives us proper information to investigate why sudden change happen in current value and it points to the actual problem or what.

The same approach can be applied to metrics such as OEE, MTBF, downtime, throughput, and asset performance.

**Now, we got clarity about the signals are not operate solely they are connected with proper contextual understanding.**

![](https://www.design-reuse-embedded.com/IMAGES/NEWS-IMAGES/2_1792051548147.webp)​​​​​​​

### Predict: Look at What May Happen Next

Now the data is connected and contextualized, now we need to trace the pattern to resolve the plant floor problems.

To solve the machine issues, we need to look about where the analytics, anomaly detection, machine learning, predictive maintenance, and physical models worked on.

May be some were processed on the edge, some run on the plant server or cloud network.

Machine raw data can also be transformed into the useful meaningful features.

*   For vibration, we may look at the RMS acceleration, frequency components, or spectral peaks.
*   For electrical behavior, we can consider the current imbalance or changes in power consumption.
*   For thermal behavior, we can track temperature drift over time.

Prediction can be happened by utilizing various machine learning models. Such as, Random Forests or LSTMs which can be used where they are suitable for application. When machine learning models such as Random Forest, or LSTMs can be used where they are appropriate for any such applications.

Physical models can also be utilized when the equipment behavior is properly understood.

Let’s take an example of the motor.

When a small change in current happens, such as rising condition occurred along with bearable temperature and vibration. The combined pattern is become more useful.

This may indicate the early degradation in pattern.

Now the question arises something different.

*   First, we asked: **“What is happening?”**
*   Now, we start asking: **“What may happen next?”**

### Recommend: Help Decide What to Do

Prediction is not the concluding part.

So, as per the last example, if the motor start showing signal of degradation, we must need to decide the further actions to be taken based on the information.

*   Should we stop the machine?
*   Should we inspect it?
*   Can we wait for the next maintenance window?

These actions depend on the real-time plant situation.

For this we need to focus on various asset criticality, production schedules, maintenance history, technician or operator availability, spare parts and other essentials availability which must not impact the line operations.

The decision flow can look like this:

**_Predictive Degradation Alert →_** **_Asset Condition + Criticality →_** **_Production Schedule + Maintenance History →_** **_Parts / Resource Availability →_** **_Recommended Action_**

The decision layer can integrate the model outcome with the operational rules, historical patterns, asset condition, production priorities, and business limitations.

So, this layer recommends about the maintenance in plant floor, it can inspect the condition, but it can not do any action on the floor.

**So, prediction now comes with the genuine alerts and recommendations.**

### Act: Connect the Decision to the Plant

This is the final step about the execute the right response.

This level of automation depends on the process of modernization. This depends on safety requirements and system permissions.

If we are looking for critical decisions on plant floor, we need to operator in the loop:

**_Recommendation → Operator / Engineer Validation → Action_**

When we do routine work, the system can raise the workflow:

**_Recommendation → Workflow / Notification → Action_**

If we are considering controlled application, the outcome/response can be automated:

**_Detection → Decision → Controlled Automated Response_**

Let us see the example, when system track the maintenance requirements, it can create proper work order in CMMS and inform technician to follow. The same workflow can be updated in MES with required information and help to prepare necessary spare parts.

In a suitable controlled environment, a permitted speed or feed rate can be adjusted. A thermal protection response can be triggered. And a predefined recovery sequence can be initiated.

But remember, these actions cannot be open loop.

These require clear limits, permissions, interlocks, and safety boundaries.

This is the important part of closed-loop operation.

**_The system does not just detect the problem. It can help drive the response toward execution._**

When these layers work together in sequence, modernization becomes more than connecting machines. Data shifts from the shop floor to context, understanding, prediction, decisions, and action.

This helps plants to improve visibility into asset health, production, quality, and emerging issues while keeping existing equipment in place. This is where MosChip’s engineering capabilities come in.

## MosChip: Enabling Legacy Modernization from Connectivity to Action

So, now when we look at the brownfield plant,

we do not start by asking what equipment requires to be replaced?

We first need to take a look into what data that machine is having and already provide the insights on signals and how to operate it with right decisions to improve operational visibility.

MosChip’s [Industrial IoT services](https://moschip.com/industrial-iot/) brings together machine monitoring, industrial connectivity, and OT-IT integration, and that enables digital manufacturing to uplift smart factory solutions to make industries connected and process accessible data across the plant.

To know more aboutMosChip’scapabilities,[drop us a line](https://moschip.com/contact-us/), and our team will get back to you.