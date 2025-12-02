package com.example.paperhub.admin;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminApplicationRepository extends JpaRepository<AdminApplication, Long> {

    Page<AdminApplication> findByStatus(AdminDtos.AdminApplicationStatus status, Pageable pageable);
}


