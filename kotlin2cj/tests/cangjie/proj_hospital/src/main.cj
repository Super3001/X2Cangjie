package proj_hospital

main() {
    let hospital = Hospital("General Hospital")
    hospital.addDoctor(Doctor("Smith", 45, "Cardiology"))
    hospital.addDoctor(Doctor("Jones", 38, "Neurology"))
    hospital.addDoctor(Doctor("Lee", 52, "Orthopedics"))
    println()
    let p1 = hospital.admitPatient("Alice", 30, "Smith")
    let p2 = hospital.admitPatient("Bob", 45, "Smith")
    let p3 = hospital.admitPatient("Charlie", 60, "Jones")
    let p4 = hospital.admitPatient("Diana", 25, "Lee")
    if (let Some(p1Value) <- p1) {
        let p1 = p1Value
        p1.addDiagnosis("Hypertension")
        p1.addDiagnosis("Arrhythmia")
    }
    if (let Some(p3Value) <- p3) {
        let p3 = p3Value
        p3.addDiagnosis("Migraine")
    }
    println()
    hospital.printStatus()
    println()
    println("Discharging Alice...")
    if (let Some(p1Value) <- p1) {
        let p1 = p1Value
        hospital.dischargePatient(p1.patientId)
    }
    println()
    hospital.printStatus()
    println()
    hospital.printAllRecords()
    println()
    println("Patient details:")
    if (let Some(p1Value) <- p1) {
        let p1 = p1Value
        p1.printRecord()
    }
    if (let Some(p2Value) <- p2) {
        let p2 = p2Value
        p2.printRecord()
    }
    if (let Some(p3Value) <- p3) {
        let p3 = p3Value
        p3.printRecord()
    }
    if (let Some(p4Value) <- p4) {
        let p4 = p4Value
        p4.printRecord()
    }
}
